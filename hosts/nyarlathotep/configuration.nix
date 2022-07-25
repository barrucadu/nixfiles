{ config, pkgs, lib, ... }:

# Bring names from 'lib' into scope.
with lib;
let
  shares = [ "anime" "manga" "misc" "music" "movies" "tv" "images" "torrents" ];

  ociBackend = config.virtualisation.oci-containers.backend;

  bookdbPort = 3000;
  floodPort = 3001;
  finderPort = 3002;
  bookmarksPort = 3003;
  grafanaPort = 3004;
  wikijsPort = 3005;
  promscalePort = 9201;
  prometheusAwairExporterPort = 9517;
in
{
  ###############################################################################
  ## General
  ###############################################################################

  networking.hostName = "nyarlathotep";
  networking.hostId = "4a592971"; # ZFS needs one of these
  boot.supportedFilesystems = [ "zfs" ];

  sops.defaultSopsFile = ./secrets.yaml;

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
  modules.eraseYourDarlings.machineId = "0f7ae3bda2a9428ab77a0adddc4c8cff";
  modules.eraseYourDarlings.barrucaduPasswordFile = config.sops.secrets."users/barrucadu".path;
  sops.secrets."users/barrucadu".neededForUsers = true;


  ###############################################################################
  ## Backups
  ###############################################################################

  services.backups.enable = true;
  services.backups.environmentFile = config.sops.secrets."services/backups/env".path;
  services.backups.pythonScripts.share = fileContents ./jobs/backup-share.py;
  sops.secrets."services/backups/env" = { };


  ###############################################################################
  ## DNS
  ###############################################################################

  services.resolved.enable = true;
  services.resolved.cache_size = 1000000;
  services.resolved.hosts_dirs = [ "/persist/etc/dns/hosts" ];
  services.resolved.zones_dirs = [ "/persist/etc/dns/zones" ];
  services.backups.scripts.resolved = ''
    cp -a /persist/etc/dns/hosts .
    cp -a /persist/etc/dns/zones .
  '';


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
    passwordFile = config.sops.secrets."users/notbarrucadu".path;
    shell = "/run/current-system/sw/bin/nologin";
  };
  sops.secrets."users/notbarrucadu".neededForUsers = true;


  ###############################################################################
  ## Reverse proxy
  ###############################################################################

  services.caddy.enable = true;
  services.caddy.extraConfig = ''
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
      reverse_proxy http://localhost:${toString config.services.bookdb.port}
    }

    http://bookmarks.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.bookmarks.port}
    }

    http://flood.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString floodPort}
    }

    http://finder.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.finder.port}
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

    http://wiki.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.wikijs.port}
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
  services.bookdb.port = bookdbPort;

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
  services.bookmarks.port = bookmarksPort;
  services.bookmarks.environmentFile = config.sops.secrets."services/bookmarks/env".path;
  sops.secrets."services/bookmarks/env" = { };

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
  services.finder.port = finderPort;
  services.finder.mangaDir = "/mnt/nas/manga";


  ###############################################################################
  ## wiki.js
  ###############################################################################

  services.wikijs.enable = true;
  services.wikijs.port = wikijsPort;


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

  systemd.services.flood = {
    enable = true;
    wantedBy = [ "default.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.flood}/bin/flood --noauth --port=${toString floodPort} --rundir=/persist/rtorrent/flood --rtsocket=/tmp/rtorrent-rpc.socket";
      User = "barrucadu";
      Restart = "on-failure";
    };
  };


  ###############################################################################
  # Monitoring & Dashboards
  ###############################################################################

  services.grafana.port = grafanaPort;
  services.grafana.rootUrl = "http://grafana.nyarlathotep.lan";
  services.grafana.provision.datasources = [
    {
      name = "promscale";
      url = "http://localhost:${toString promscalePort}";
      type = "prometheus";
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
      job_name = "awair";
      static_configs = [{ targets = [ "localhost:${toString prometheusAwairExporterPort}" ]; }];
    }
  ];

  systemd.services.prometheus-awair-exporter =
    let
      package = { buildGoModule, fetchFromGitHub, ... }: buildGoModule rec {
        pname = "prometheus-awair-exporter";
        version = "f154bbdc401886a1311d80d19d4461a0915ed310";

        src = fetchFromGitHub {
          owner = "barrucadu";
          repo = pname;
          rev = version;
          sha256 = "180ys8ghm82l2l53wz3bhhjqjvrj4a2iv0xq66w9dbvsyw2mc863";
        };

        vendorSha256 = "1px1zzfihhdazaj31id1nxl6b09vy2yxj6wz5gv5f7mzdqdlmxxl";
      };
      prometheus_awair_exporter = pkgs.callPackage package { };
    in
    {
      description = "barrucadu/prometheus-awair-exporter metrics exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${prometheus_awair_exporter}/bin/prometheus-awair-exporter --address 127.0.0.1:${toString prometheusAwairExporterPort} --sensor living-room:10.0.20.117 --sensor bedroom:10.0.20.187";
        DynamicUser = "true";
        Restart = "on-failure";
      };
    };


  ###############################################################################
  ## Docker registry (currently just used on this machine)
  ###############################################################################

  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableGarbageCollect = true;
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
  # Finance dashboard & FX rate fetching
  ###############################################################################

  systemd.timers.hledger-fetch-fx-rates = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 21:00:00";
    };
  };
  systemd.services.hledger-fetch-fx-rates = {
    description = "Download GBP exchange rates for commodities";
    path = with pkgs; [ hledger ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${pkgs.writeText "hledger-fetch-fx-rates.py" (fileContents ./jobs/hledger-fetch-fx-rates.py)}";
      User = "barrucadu";
      Group = "users";
    };
    environment = {
      PYTHONPATH =
        let penv = pkgs.python3.buildEnv.override { extraLibs = with pkgs.python3Packages; [ requests ]; };
        in "${penv}/${pkgs.python3.sitePackages}/";
      PRICE_FILE = "/home/barrucadu/s/ledger/prices";
    };
  };

  systemd.timers.hledger-export-to-promscale = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
    };
  };
  systemd.services.hledger-export-to-promscale = {
    description = "Export personal finance data to promscale";
    path = with pkgs; [ hledger ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${pkgs.writeText "hledger-export-to-promscale.py" (fileContents ./jobs/hledger-export-to-promscale.py)}";
      User = "barrucadu";
      Group = "users";
    };
    environment = {
      PYTHONPATH =
        let penv = pkgs.python3.buildEnv.override { extraLibs = with pkgs.python3Packages; [ requests ]; };
        in "${penv}/${pkgs.python3.sitePackages}/";
      LEDGER_FILE = "/home/barrucadu/s/ledger/combined.journal";
      PROMSCALE_URI = "http://localhost:${toString promscalePort}";
    };
  };

  virtualisation.oci-containers.containers.promscale = {
    autoStart = true;
    image = "timescale/promscale:latest";
    cmd = [ "-db.host=promscale-db" "-db.name=postgres" "-db.password=promscale" "-db.ssl-mode=allow" "-web.enable-admin-api=true" "-metrics.promql.lookback-delta=168h" ];
    extraOptions = [ "--network=promscale_network" ];
    dependsOn = [ "promscale-db" ];
    ports = [ "127.0.0.1:${toString promscalePort}:9201" ];
  };
  virtualisation.oci-containers.containers.promscale-db = {
    autoStart = true;
    image = "timescaledev/promscale-extension:latest-ts2-pg14";
    environment = {
      POSTGRES_PASSWORD = "promscale";
    };
    extraOptions = [ "--network=promscale_network" ];
    volumes = [ "/persist/docker-volumes/promscale/pgdata:/var/lib/postgresql/data" ];
  };
  systemd.services."${ociBackend}-promscale-db".preStart = "${ociBackend} network create -d bridge promscale_network || true";
}
