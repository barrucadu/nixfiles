{ config, pkgs, lib, ... }:

# Bring names from 'lib' into scope.
with lib;

let
  shares = [ "anime" "manga" "misc" "music" "movies" "tv" "images" "torrents" ];
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
  services.monitoring-scripts.OnCalendar = "0/12:00:00";

  # Bootloader
  boot.loader.systemd-boot.enable = true;

  # Enable memtest
  boot.loader.systemd-boot.memtest86.enable = true;

  # Monthly ZFS scrub
  services.zfs.autoScrub.enable = true;
  services.zfs.autoScrub.interval = "monthly";

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "lo" "docker0" "enp4s0" ];
  networking.firewall.allowedTCPPorts = [ 8888 ]; # for testing stuff


  ###############################################################################
  ## Make / volatile
  ###############################################################################

  boot.initrd.postDeviceCommands = mkAfter ''
    zfs rollback -r local/volatile/root@blank
  '';

  # Switch back to immutable users
  users.mutableUsers = mkForce false;
  users.extraUsers.barrucadu.initialPassword = mkForce null;
  users.extraUsers.barrucadu.hashedPassword = fileContents /etc/nixos/secrets/passwd-barrucadu.txt;

  # Store data in /persist (see also configuration elsewhere in this
  # file)
  services.openssh.hostKeys = [
    {
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/persist/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  services.syncthing.dataDir = "/persist/var/lib/syncthing";

  systemd.tmpfiles.rules = [
    "L+ /etc/nixos - - - - /persist/etc/nixos"
  ];


  ###############################################################################
  ## Network storage
  ###############################################################################

  # NFS exports
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /mnt/nas/ *(rw,fsid=root,no_subtree_check)
    ${concatMapStringsSep "\n" (n: "/mnt/nas/${n} *(rw,no_subtree_check,nohide)") shares}
  '';

  # Samba
  services.samba.enable = true;
  services.samba.shares = listToAttrs
    (map (n: nameValuePair n { path = "/mnt/nas/${n}"; writable = "yes"; }) shares);
  services.samba.extraConfig = ''
    log file = /var/log/samba/%m.log
    private dir = /persist/var/lib/samba/private
  '';

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
        root /persist/srv/http/nyarlathotep.lan
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
      reverse_proxy http://localhost:3001
    }

    http://finder.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.finder.httpPort}
    }

    http://prometheus.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.prometheus.port}
    }

    http://grafana.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.grafana.port}
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
        root /persist/srv/http/vlan1.help.lan
      }
    }

    http://vlan10.help.lan:80 {
      import vlan_matchers
      encode gzip
      redir @not_vlan10 http://help.lan 302
      file_server {
        root /persist/srv/http/vlan10.help.lan
      }
    }

    http://vlan20.help.lan:80 {
      import vlan_matchers
      encode gzip
      redir @not_vlan20 http://help.lan 302
      file_server {
        root /persist/srv/http/vlan20.help.lan
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
  services.bookdb.dockerVolumeDir = /persist/docker-volumes/bookdb;

  systemd.timers.bookdb-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
    };
  };
  systemd.services.bookdb-sync = {
    description = "Upload bookdb data to dunwich";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ${pkgs.writeShellScript "bookdb-sync.sh" (fileContents ./bookdb-sync.sh)}";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };


  ###############################################################################
  ## bookmarks - https://github.com/barrucadu/bookmarks
  ###############################################################################

  services.bookmarks.enable = true;
  services.bookmarks.image = "localhost:5000/bookmarks:latest";
  services.bookmarks.baseURI = "http://bookmarks.nyarlathotep.lan";
  services.bookmarks.httpPort = 3003;
  services.bookmarks.youtubeApiKey = fileContents /etc/nixos/secrets/bookmarks-youtube-api-key.txt;
  services.bookmarks.dockerVolumeDir = /persist/docker-volumes/bookmarks;

  systemd.timers.bookmarks-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
    };
  };
  systemd.services.bookmarks-sync = {
    description = "Upload bookmarks data to dunwich";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ${pkgs.writeShellScript "bookmarks-sync.sh" (fileContents ./bookmarks-sync.sh)}";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };


  ###############################################################################
  ## finder
  ###############################################################################

  services.finder.enable = true;
  services.finder.image = "localhost:5000/finder:latest";
  services.finder.httpPort = 3002;
  services.finder.dockerVolumeDir = /persist/docker-volumes/finder;
  services.finder.mangaDir = /mnt/nas/manga;


  ###############################################################################
  ## rTorrent
  ###############################################################################

  systemd.services.rtorrent =
    let
      rtorrentrc = pkgs.writeText "rtorrent.rc" (fileContents ./rtorrent.rc);
    in
      {
        enable   = true;
        wantedBy = [ "default.target" ];
        after    = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.rtorrent}/bin/rtorrent -n -o system.daemon.set=true -o import=${rtorrentrc}";
          User      = "barrucadu";
          Restart   = "on-failure";
        };
      };

  # todo: either dockerise this or properly package it
  systemd.services.flood = {
    enable   = true;
    wantedBy = [ "default.target" ];
    after    = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.zsh}/bin/zsh --login -c '${pkgs.nodejs-12_x}/bin/npm start'";
      User      = "barrucadu";
      KillMode  = "none";
      Restart   = "on-failure";
      WorkingDirectory = "/persist/flood";
    };
  };


  ###############################################################################
  # Monitoring & Dashboards
  ###############################################################################

  services.grafana = {
    enable = true;
    port = 3004;
    rootUrl = "http://grafana.nyarlathotep.lan";
    dataDir = "/persist/var/lib/grafana";
    provision = {
      enable = true;
      datasources = [
        {
          name = "prometheus";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          type = "prometheus";
        }
        {
          name = "finance";
          url = "http://localhost:8086";
          type = "influxdb";
          database = "finance";
        }
      ];
      dashboards =
        let
          dashboard = folder: name: path: { name = name; folder = folder; options.path = pkgs.writeTextDir name (fileContents path); };
        in
          [
            (dashboard "My Dashboards" "overview.json" ./grafana-dashboards/overview.json)
            (dashboard "My Dashboards" "finance.json" ./grafana-dashboards/finance.json)
            (dashboard "UniFi" "unifi-poller-client-dpi.json" ./grafana-dashboards/unifi-poller-client-dpi.json)
            (dashboard "UniFi" "unifi-poller-client-insights.json" ./grafana-dashboards/unifi-poller-client-insights.json)
            (dashboard "UniFi" "unifi-poller-network-sites.json" ./grafana-dashboards/unifi-poller-network-sites.json)
            (dashboard "UniFi" "unifi-poller-uap-insights.json" ./grafana-dashboards/unifi-poller-uap-insights.json)
            (dashboard "UniFi" "unifi-poller-usg-insights.json" ./grafana-dashboards/unifi-poller-usg-insights.json)
            (dashboard "UniFi" "unifi-poller-usw-insights.json" ./grafana-dashboards/unifi-poller-usw-insights.json)
          ];
    };
  };

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    globalConfig.scrape_interval = "15s";
    scrapeConfigs = [
      {
        job_name = "nyarlathotep-node";
        static_configs = [ { targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ]; } ];
      }
      {
        job_name = "nyarlathotep-docker";
        static_configs = [ { targets = [ "localhost:9417" ]; } ];
      }
      {
        job_name = "pihole-node";
        static_configs = [ { targets = [ "pi.hole:9100" ]; } ];
      }
      {
        job_name = "pihole-pihole";
        static_configs = [ { targets = [ "pi.hole:9617" ]; } ];
      }
      {
        job_name = "speedtest";
        scrape_interval = "5m";
        scrape_timeout = "2m";
        static_configs = [ { targets = [ "localhost:9516" ]; } ];
      }
      {
        job_name = "unifipoller";
        static_configs = [ { targets = [ "localhost:9130" ]; } ];
      }
    ];
    webExternalUrl = "http://prometheus.nyarlathotep.lan";
    exporters.node.enable = true;
  };

  # systemd doesn't like using a symlink for a StateDirectory, but a
  # bind mount works fine.
  systemd.services.prometheus-statedir = {
    enable = true;
    description = "Bind-mount prometheus StateDirectory";
    after = ["local-fs.target"];
    wantedBy = ["prometheus.service"];
    serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /var/lib/${config.services.prometheus.stateDir}";
    serviceConfig.ExecStart = "${pkgs.utillinux}/bin/mount -o bind /persist/var/lib/${config.services.prometheus.stateDir} /var/lib/${config.services.prometheus.stateDir}";
  };

  systemd.services.prometheus-docker-exporter = {
    enable = true;
    description = "Docker exporter for Prometheus";
    after = ["docker.service"];
    wantedBy = ["prometheus.service"];
    serviceConfig.Restart = "always";
    serviceConfig.ExecStartPre = [
      "-${pkgs.docker}/bin/docker stop prometheus_docker_exporter"
      "-${pkgs.docker}/bin/docker rm prometheus_docker_exporter"
      "${pkgs.docker}/bin/docker pull prometheusnet/docker_exporter"
    ];
    serviceConfig.ExecStart = "${pkgs.docker}/bin/docker run --rm --name prometheus_docker_exporter --volume \"/var/run/docker.sock\":\"/var/run/docker.sock\" --publish 9417:9417 prometheusnet/docker_exporter";
  };

  systemd.services.prometheus-speedtest-exporter = {
    enable = true;
    description = "Speedtest.net exporter for Prometheus";
    after = ["docker.service"];
    wantedBy = ["prometheus.service"];
    serviceConfig.Restart = "always";
    serviceConfig.ExecStartPre = [
      "-${pkgs.docker}/bin/docker stop prometheus_speedtest_exporter"
      "-${pkgs.docker}/bin/docker rm prometheus_speedtest_exporter"
    ];
    serviceConfig.ExecStart = "${pkgs.docker}/bin/docker run --rm --name prometheus_speedtest_exporter --publish 9516:8888 localhost:5000/prometheus-speedtest-exporter";
  };

  systemd.services.prometheus-unifipoller-exporter = {
    enable = true;
    description = "UniFi Poller exporter for Prometheus";
    after = ["docker.service"];
    wantedBy = ["prometheus.service"];
    serviceConfig.Restart = "always";
    serviceConfig.ExecStartPre = [
      "-${pkgs.docker}/bin/docker stop prometheus_unifipoller_exporter"
      "-${pkgs.docker}/bin/docker rm prometheus_unifipoller_exporter"
    ];
    serviceConfig.ExecStart = "${pkgs.docker}/bin/docker run --rm --name prometheus_unifipoller_exporter -e UP_UNIFI_DEFAULT_URL=https://router.lan -e UP_UNIFI_DEFAULT_PASS=${fileContents /etc/nixos/secrets/unifipoller-password.txt} -e UP_UNIFI_DEFAULT_SAVE_DPI=true -e UP_INFLUXDB_DISABLE=true --publish 9130:9130 golift/unifi-poller";
  };


  ###############################################################################
  ## Docker registry (currently just used on this machine)
  ###############################################################################

  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableGarbageCollect = true;
  services.dockerRegistry.storagePath = "/persist/var/lib/docker-registry";
  virtualisation.docker.extraOptions = "--insecure-registry=localhost:5000";


  ###############################################################################
  # Automatic music tagging
  ###############################################################################

  systemd.services.tag-podcasts = {
    enable = true;
    description = "Automatically tag new podcast files";
    wantedBy = ["multi-user.target"];
    path = with pkgs; [ inotifyTools id3v2 ];
    unitConfig.RequiresMountsFor = "/mnt/nas";
    serviceConfig = {
      WorkingDirectory = "/mnt/nas/music/Podcasts/";
      ExecStart = pkgs.writeShellScript "tag-podcasts.sh" (fileContents ./tag-podcasts.sh);
      User = "barrucadu";
      Group = "users";
      Restart = "always";
    };
  };

  systemd.paths.flac-and-tag-album = {
    enable = true;
    description = "Automatically flac and tag new albums";
    wantedBy = ["multi-user.target"];
    unitConfig.RequiresMountsFor = "/mnt/nas";
    pathConfig.PathExistsGlob = "/mnt/nas/music/to_convert/in/*";
  };
  systemd.services.flac-and-tag-album = {
    path = with pkgs; [ flac ];
    serviceConfig = {
      WorkingDirectory = "/mnt/nas/music/to_convert/in/";
      ExecStart = pkgs.writeShellScript "flac-and-tag-album.sh" (fileContents ./flac-and-tag-album.sh);
      User = "barrucadu";
      Group = "users";
    };
  };


  ###############################################################################
  # Daily hledger price fetch & influxdb import
  ###############################################################################

  services.influxdb.enable = true;
  services.influxdb.dataDir = "/persist/var/lib/influxdb";

  systemd.timers.hledger-scripts = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 21:00:00";
    };
  };
  systemd.services.hledger-scripts = {
    description = "Run hledger scripts";
    serviceConfig.WorkingDirectory = "/home/barrucadu/projects/hledger-scripts";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c './sync.sh'";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };


  ###############################################################################
  ## Extra packages
  ###############################################################################

  environment.systemPackages = with pkgs;
    [
      mktorrent
      nodejs-12_x
      tmux
    ];
}
