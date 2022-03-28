{ config, pkgs, lib, ... }:

# Bring names from 'lib' into scope.
with lib;
let
  shares = [ "anime" "manga" "misc" "music" "movies" "tv" "images" "torrents" ];

  ociBackend = config.virtualisation.oci-containers.backend;
  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };

  bookdbPort = 3000;
  floodPort = 3001;
  finderPort = 3002;
  bookmarksPort = 3003;
  grafanaPort = 3004;
in
{
  ###############################################################################
  ## General
  ###############################################################################

  networking.hostName = "nyarlathotep";
  networking.hostId = "4a592971"; # ZFS needs one of these
  boot.supportedFilesystems = [ "zfs" ];

  # Only run monitoring scripts every 12 hours: I can't replace a
  # broken HDD if I'm away from home.
  modules.monitoringScripts.onCalendar = "0/12:00:00";

  # Bootloader
  boot.loader.systemd-boot.enable = true;

  # Enable memtest
  boot.loader.systemd-boot.memtest86.enable = true;

  # ZFS auto trim, scrub, & snapshot
  modules.zfsAutomation.enable = true;

  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 8888 111 2049 4000 4001 4002 ];

  # Wipe / on boot
  modules.eraseYourDarlings.enable = true;
  modules.eraseYourDarlings.barrucaduHashedPassword = fileContents /etc/nixos/secrets/passwd-barrucadu.txt;


  ###############################################################################
  ## DNS
  ###############################################################################

  services.resolved.enable = true;
  services.resolved.cache_size = 1000000;
  services.resolved.hosts_dirs = [ "/persist/etc/dns/hosts" ];
  services.resolved.zones_dirs = [ "/persist/etc/dns/zones" ];


  ###############################################################################
  ## Network storage
  ###############################################################################

  # NFS exports
  services.nfs.server.enable = true;
  services.nfs.server.mountdPort = 4002;
  services.nfs.server.lockdPort = 4001;
  services.nfs.server.statdPort = 4000;
  services.nfs.server.exports = ''
    /mnt/nas/ *(rw,fsid=root,no_subtree_check)
    ${concatMapStringsSep "\n" (n: "/mnt/nas/${n} *(rw,no_subtree_check,nohide)") shares}
  '';

  # Samba
  services.samba.enable = true;
  services.samba.openFirewall = true;
  services.samba.shares = listToAttrs
    (map (n: nameValuePair n { path = "/mnt/nas/${n}"; writable = "yes"; }) shares);

  # Guest user for NFS / Samba
  users.extraUsers.notbarrucadu = {
    uid = 1001;
    description = "Guest user";
    isNormalUser = true;
    group = "users";
    hashedPassword = fileContents /etc/nixos/secrets/passwd-notbarrucadu.txt;
    shell = "/run/current-system/sw/bin/nologin";
  };


  ###############################################################################
  ## Reverse proxy
  ###############################################################################

  services.caddy.enable = true;
  services.caddy.config = ''
    (vlan_matchers) {
      @vlan1 remote_ip 10.0.0.0/24
      @not_vlan1 not remote_ip 10.0.0.0/24

      @vlan10 remote_ip 10.0.10.0/24
      @not_vlan10 not remote_ip 10.0.10.0/24

      @vlan20 remote_ip 10.0.20.0/24
      @not_vlan20 not remote_ip 10.0.20.0/24
    }

    (restrict_vlan) {
      import vlan_matchers
      redir @vlan20 http://help.lan 307
    }

    http://nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      file_server {
        root ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/nyarlathotep.lan
      }
    }

    http://bookdb.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.bookdb.httpPort}
    }

    http://bookmarks.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.bookmarks.httpPort}
    }

    http://flood.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString floodPort}
    }

    http://finder.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.finder.httpPort}
    }

    http://grafana.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.grafana.port}
    }

    http://prometheus.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.prometheus.port}
    }

    http://help.lan:80 {
      import vlan_matchers
      redir @vlan1 http://vlan1.help.lan 302
      redir @vlan10 http://vlan10.help.lan 302
      redir @vlan20 http://vlan20.help.lan 302
    }

    http://vlan1.help.lan:80 {
      import vlan_matchers
      encode gzip
      redir @not_vlan1 http://help.lan 302
      file_server {
        root ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/vlan1.help.lan
      }
    }

    http://vlan10.help.lan:80 {
      import vlan_matchers
      encode gzip
      redir @not_vlan10 http://help.lan 302
      file_server {
        root ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/vlan10.help.lan
      }
    }

    http://vlan20.help.lan:80 {
      import vlan_matchers
      encode gzip
      redir @not_vlan20 http://help.lan 302
      file_server {
        root ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/vlan20.help.lan
      }
    }

    http://*:80 {
      respond * 421
    }
  '';


  ###############################################################################
  ## bookdb - https://github.com/barrucadu/bookdb
  ###############################################################################

  services.bookdb.enable = true;
  services.bookdb.image = "localhost:5000/bookdb:latest";
  services.bookdb.baseURI = "http://bookdb.nyarlathotep.lan";
  services.bookdb.httpPort = bookdbPort;

  systemd.timers.bookdb-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
    };
  };
  systemd.services.bookdb-sync = {
    description = "Upload bookdb data to carcosa";
    path = with pkgs; [ docker openssh ];
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "bookdb-sync.sh" (fileContents ./jobs/bookdb-sync.sh);
      User = "barrucadu";
      Group = "users";
    };
  };


  ###############################################################################
  ## bookmarks - https://github.com/barrucadu/bookmarks
  ###############################################################################

  services.bookmarks.enable = true;
  services.bookmarks.image = "localhost:5000/bookmarks:latest";
  services.bookmarks.baseURI = "http://bookmarks.nyarlathotep.lan";
  services.bookmarks.httpPort = bookmarksPort;
  services.bookmarks.youtubeApiKey = fileContents /etc/nixos/secrets/bookmarks-youtube-api-key.txt;

  systemd.timers.bookmarks-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
    };
  };
  systemd.services.bookmarks-sync = {
    description = "Upload bookmarks data to carcosa";
    path = with pkgs; [ docker openssh ];
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "bookmarks-sync.sh" (fileContents ./jobs/bookmarks-sync.sh);
      User = "barrucadu";
      Group = "users";
    };
  };


  ###############################################################################
  ## finder
  ###############################################################################

  services.finder.enable = true;
  services.finder.image = "localhost:5000/finder:latest";
  services.finder.httpPort = finderPort;
  services.finder.mangaDir = "/mnt/nas/manga";


  ###############################################################################
  ## rTorrent
  ###############################################################################

  systemd.services.rtorrent =
    let
      rtorrentrc = pkgs.writeText "rtorrent.rc" (fileContents ./rtorrent.rc);
    in
    {
      enable = true;
      wantedBy = [ "default.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.rtorrent}/bin/rtorrent -n -o system.daemon.set=true -o import=${rtorrentrc}";
        User = "barrucadu";
        Restart = "on-failure";
      };
    };

  # todo: either dockerise this or properly package it
  systemd.services.flood = {
    enable = true;
    wantedBy = [ "default.target" ];
    after = [ "network.target" ];
    path = [ pkgs.bash pkgs.nodejs-12_x ];
    serviceConfig = {
      ExecStart = "${pkgs.nodejs-12_x}/bin/npm start";
      User = "barrucadu";
      KillMode = "none";
      Restart = "on-failure";
      WorkingDirectory = "${toString config.modules.eraseYourDarlings.persistDir}/flood";
    };
  };


  ###############################################################################
  # Monitoring & Dashboards
  ###############################################################################

  services.grafana.port = grafanaPort;
  services.grafana.rootUrl = "http://grafana.nyarlathotep.lan";
  services.grafana.provision.datasources = [
    {
      name = "finance";
      url = "http://localhost:8086";
      type = "influxdb";
      database = "finance";
    }
  ];
  services.grafana.provision.dashboards =
    let
      dashboard = folder: name: path: { inherit name folder; options.path = path; };
    in
    [
      (dashboard "My Dashboards" "finance.json" ./grafana-dashboards/finance.json)
      (dashboard "My Dashboards" "smart-home.json" ./grafana-dashboards/smart-home.json)
    ];

  services.prometheus.webExternalUrl = "http://prometheus.nyarlathotep.lan";
  services.prometheus.scrapeConfigs = [
    {
      job_name = "speedtest";
      scrape_interval = "5m";
      scrape_timeout = "2m";
      static_configs = [{ targets = [ "localhost:9516" ]; }];
    }
    {
      job_name = "awair";
      static_configs = [{ targets = [ "localhost:9517" ]; }];
    }
  ];

  virtualisation.oci-containers.containers.prometheus-speedtest-exporter = {
    autoStart = true;
    image = "localhost:5000/prometheus-speedtest-exporter";
    ports = [ "127.0.0.1:9516:8888" ];
  };
  systemd.services."${ociBackend}-prometheus-speedtest-exporter" = {
    wantedBy = [ "prometheus.service" ];
    serviceConfig = serviceConfigForContainerLogging;
  };

  virtualisation.oci-containers.containers.prometheus-awair-exporter = {
    autoStart = true;
    image = "localhost:5000/prometheus-awair-exporter";
    environment = {
      "SENSORS" = "living-room=10.0.20.117";
    };
    ports = [ "127.0.0.1:9517:8888" ];
  };
  systemd.services."${ociBackend}-prometheus-awair-exporter" = {
    wantedBy = [ "prometheus.service" ];
    serviceConfig = serviceConfigForContainerLogging;
  };


  ###############################################################################
  ## Docker registry (currently just used on this machine)
  ###############################################################################

  services.dockerRegistry.enable = true;
  virtualisation.docker.extraOptions = "--insecure-registry=localhost:5000";


  ###############################################################################
  # Automatic music tagging
  ###############################################################################

  systemd.services.tag-podcasts = {
    enable = true;
    description = "Automatically tag new podcast files";
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ inotifyTools id3v2 ];
    unitConfig.RequiresMountsFor = "/mnt/nas";
    serviceConfig = {
      WorkingDirectory = "/mnt/nas/music/Podcasts/";
      ExecStart = pkgs.writeShellScript "tag-podcasts.sh" (fileContents ./jobs/tag-podcasts.sh);
      User = "barrucadu";
      Group = "users";
      Restart = "always";
    };
  };

  systemd.paths.flac-and-tag-album = {
    enable = true;
    description = "Automatically flac and tag new albums";
    wantedBy = [ "multi-user.target" ];
    unitConfig.RequiresMountsFor = "/mnt/nas";
    pathConfig.PathExistsGlob = "/mnt/nas/music/to_convert/in/*";
  };
  systemd.services.flac-and-tag-album = {
    path = with pkgs; [ flac ];
    serviceConfig = {
      WorkingDirectory = "/mnt/nas/music/to_convert/in/";
      ExecStart = pkgs.writeShellScript "flac-and-tag-album.sh" (fileContents ./jobs/flac-and-tag-album.sh);
      User = "barrucadu";
      Group = "users";
    };
  };


  ###############################################################################
  # https://github.com/barrucadu/hledger-scripts
  ###############################################################################

  services.influxdb.enable = true;
  # override collectd config to not pull in the collectd-data package
  services.influxdb.extraConfig = { collectd = [{ enabled = false; }]; };

  systemd.timers.hledger-scripts = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 21:00:00";
    };
  };
  systemd.services.hledger-scripts = {
    description = "Run hledger scripts";
    serviceConfig.WorkingDirectory = "/home/barrucadu/projects/hledger-scripts";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c 'env LEDGER_FILE=/home/barrucadu/s/ledger/combined.journal ./sync.sh'";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };
}
