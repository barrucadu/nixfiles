{ config, pkgs, lib, ... }:

# Bring names from 'lib' into scope.
with lib;
let
  shares = [ "anime" "manga" "misc" "music" "movies" "tv" "images" "torrents" ];

  bookdbPort = 3000;
  floodPort = 3001;
  finderPort = 3002;
  bookmarksPort = 3003;
  grafanaPort = 3004;
  promscalePort = 9201;
  prometheusAwairExporterPort = 9517;

  rtorrentExternalPort = 50000;

  httpdir = "${toString config.nixfiles.eraseYourDarlings.persistDir}/srv/http";
in
{
  ###############################################################################
  ## General
  ###############################################################################

  networking.hostId = "4a592971"; # ZFS needs one of these
  boot.supportedFilesystems = [ "zfs" ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;

  # Enable memtest
  boot.loader.systemd-boot.memtest86.enable = true;

  # Firewall
  networking.firewall.allowedTCPPorts = [
    80
    8888
    111 # NFS
    2049 # NFS
    config.services.nfs.server.mountdPort
    config.services.nfs.server.lockdPort
    config.services.nfs.server.statdPort
    rtorrentExternalPort
  ];

  # Wipe / on boot
  nixfiles.eraseYourDarlings.enable = true;
  nixfiles.eraseYourDarlings.machineId = "0f7ae3bda2a9428ab77a0adddc4c8cff";
  nixfiles.eraseYourDarlings.barrucaduPasswordFile = config.sops.secrets."users/barrucadu".path;
  sops.secrets."users/barrucadu".neededForUsers = true;


  ###############################################################################
  ## Backups
  ###############################################################################

  nixfiles.backups.enable = true;
  nixfiles.backups.environmentFile = config.sops.secrets."nixfiles/backups/env".path;
  nixfiles.backups.pythonScripts.share = fileContents ./jobs/backup-share.py;
  sops.secrets."nixfiles/backups/env" = { };


  ###############################################################################
  ## DNS
  ###############################################################################

  nixfiles.resolved.enable = true;
  nixfiles.resolved.cache_size = 1000000;
  nixfiles.resolved.hosts_dirs = [ "/etc/dns/hosts" ];
  nixfiles.resolved.zones_dirs = [ "/etc/dns/zones" ];

  environment.etc."dns/hosts/stevenblack".source = builtins.fetchurl {
    url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts";
    sha256 = "0zh5184apb1c6mv8sabfwlg49s6xxapwxq5qid7d48786xggq6wi";
  };

  environment.etc."dns/zones/10.in-addr.arpa".text = ''
    $ORIGIN 10.in-addr.arpa.

    @ IN SOA . . 3 3600 3600 3600 3600

    1.0.0    IN PTR router.lan.
    3.0.0    IN PTR nyarlathotep.lan.
    187.20.0 IN PTR bedroom.awair.lan.
    117.20.0 IN PTR living-room.awair.lan.
  '';

  environment.etc."dns/zones/lan".text = ''
    $ORIGIN lan.

    @ 300 IN SOA @ @ 6 300 300 300 300

    router            300 IN A     10.0.0.1

    nyarlathotep      300 IN A     10.0.0.3
    *.nyarlathotep    300 IN CNAME nyarlathotep

    help              300 IN CNAME nyarlathotep
    *.help            300 IN CNAME help

    nas               300 IN CNAME nyarlathotep

    bedroom.awair     300 IN A     10.0.20.187
    living-room.awair 300 IN A     10.0.20.117
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
        root ${httpdir}/nyarlathotep.lan
      }
    }

    http://alertmanager.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.prometheus.alertmanager.port}
    }

    http://bookdb.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.nixfiles.bookdb.port}
    }

    http://bookmarks.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.nixfiles.bookmarks.port}
    }

    http://flood.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString floodPort}
    }

    http://finder.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.nixfiles.finder.port}
    }

    http://grafana.nyarlathotep.lan:80 {
      import restrict_vlan
      encode gzip
      reverse_proxy http://localhost:${toString config.services.grafana.settings.server.http_port}
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
        root ${httpdir}/vlan1.help.lan
      }
    }

    http://vlan10.help.lan:80 {
      import vlan_matchers
      encode gzip
      redir @not_vlan10 http://help.lan 302
      file_server {
        root ${httpdir}/vlan10.help.lan
      }
    }

    http://vlan20.help.lan:80 {
      import vlan_matchers
      encode gzip
      redir @not_vlan20 http://help.lan 302
      file_server {
        root ${httpdir}/vlan20.help.lan
      }
    }

    http://*:80 {
      respond * 421
    }
  '';


  ###############################################################################
  ## bookdb - https://github.com/barrucadu/bookdb
  ###############################################################################

  nixfiles.bookdb.enable = true;
  nixfiles.bookdb.image = "localhost:5000/bookdb:latest";
  nixfiles.bookdb.baseURI = "http://bookdb.nyarlathotep.lan";
  nixfiles.bookdb.port = bookdbPort;

  systemd.services.bookdb-sync = {
    description = "Upload bookdb data to carcosa";
    startAt = "hourly";
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

  nixfiles.bookmarks.enable = true;
  nixfiles.bookmarks.image = "localhost:5000/bookmarks:latest";
  nixfiles.bookmarks.baseURI = "http://bookmarks.nyarlathotep.lan";
  nixfiles.bookmarks.port = bookmarksPort;
  nixfiles.bookmarks.environmentFile = config.sops.secrets."nixfiles/bookmarks/env".path;
  sops.secrets."nixfiles/bookmarks/env" = { };

  systemd.services.bookmarks-sync = {
    description = "Upload bookmarks data to carcosa";
    startAt = "hourly";
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

  nixfiles.finder.enable = true;
  nixfiles.finder.image = "localhost:5000/finder:latest";
  nixfiles.finder.port = finderPort;
  nixfiles.finder.mangaDir = "/mnt/nas/manga";


  ###############################################################################
  ## rTorrent
  ###############################################################################

  systemd.services.rtorrent =
    let
      downloadDir = "/mnt/nas/torrents/files/";
      watchDir = "/mnt/nas/torrents/watch/";
      sessionDir = "/persist/rtorrent/session/";
      logDir = "/persist/rtorrent/logs/";
      rpcSock = "/run/rtorrent/rpc.sock";

      rtorrentrc = pkgs.writeText "rtorrent.rc" ''
        # Paths
        directory.default.set = ${downloadDir}
        session.path.set      = ${sessionDir}

        # Logging
        method.insert = cfg.logfile, private|const|string, (cat,"${logDir}",(system.time),".log")
        log.open_file = "log", (cfg.logfile)
        log.add_output = "info", "log"

        # Listening port for incoming peer traffic
        network.port_range.set  = ${toString rtorrentExternalPort}-${toString rtorrentExternalPort}
        network.port_random.set = no

        # Optimise for private trackers (disable DHT & UDP trackers)
        dht.mode.set         = disable
        protocol.pex.set     = no
        trackers.use_udp.set = no

        # Force encryption
        protocol.encryption.set = allow_incoming,try_outgoing,require,require_RC4

        # Write filenames in UTF-8
        encoding.add = UTF-8

        # Check hash on completion
        pieces.hash.on_completion.set = yes

        # Monitor for new .torrent files
        schedule2 = watch_directory,5,5,load.start=${watchDir}*.torrent

        # XMLRPC
        network.scgi.open_local = ${rpcSock}
      '';
    in
    {
      enable = true;
      wantedBy = [ "default.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.rtorrent}/bin/rtorrent -n -o system.daemon.set=true -o import=${rtorrentrc}";
        User = "barrucadu";
        Restart = "on-failure";
        RuntimeDirectory = "rtorrent";
        # with a lot of torrents, rtorrent can take a while to shut down
        TimeoutStopSec = 300;
      };
    };

  systemd.services.flood = {
    enable = true;
    wantedBy = [ "default.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.flood}/bin/flood --noauth --port=${toString floodPort} --rundir=/persist/rtorrent/flood --rtsocket=/run/rtorrent/rpc.sock";
      User = "barrucadu";
      Restart = "on-failure";
    };
  };


  ###############################################################################
  # Monitoring & Dashboards
  ###############################################################################

  services.prometheus.alertmanager.environmentFile = config.sops.secrets."services/alertmanager/env".path;
  sops.secrets."services/alertmanager/env" = { };

  services.grafana = {
    settings = {
      server.http_port = grafanaPort;
      server.root_url = "http://grafana.nyarlathotep.lan";
    };
    provision = {
      datasources.settings.datasources = [
        {
          name = "promscale";
          url = "http://localhost:${toString promscalePort}";
          type = "prometheus";
        }
      ];
      dashboards.settings.providers =
        let
          dashboard = folder: name: path: { inherit name folder; options.path = path; };
        in
        [
          (dashboard "My Dashboards" "finance.json" ./dashboards/finance.json)
          (dashboard "My Dashboards" "smart-home.json" ./dashboards/smart-home.json)
        ];
    };
  };

  services.prometheus.webExternalUrl = "http://prometheus.nyarlathotep.lan";
  services.prometheus.scrapeConfigs = [
    {
      job_name = "awair";
      static_configs = [{ targets = [ "localhost:${toString prometheusAwairExporterPort}" ]; }];
    }
  ];

  systemd.services.prometheus-awair-exporter =
    {
      description = "barrucadu/prometheus-awair-exporter metrics exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.nixfiles.prometheus-awair-exporter}/bin/prometheus-awair-exporter --address 127.0.0.1:${toString prometheusAwairExporterPort} --sensor living-room:10.0.20.117 --sensor bedroom:10.0.20.187";
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

  systemd.services.hledger-fetch-fx-rates = {
    description = "Download GBP exchange rates for commodities";
    startAt = "*-*-* 21:00:00";
    path = with pkgs; [ hledger ];
    serviceConfig = {
      ExecStart =
        let python = pkgs.python3.withPackages (ps: [ ps.requests ]);
        in "${python}/bin/python3 ${pkgs.writeText "hledger-fetch-fx-rates.py" (fileContents ./jobs/hledger-fetch-fx-rates.py)}";
      User = "barrucadu";
      Group = "users";
    };
    environment = {
      PRICE_FILE = "/home/barrucadu/s/ledger/prices";
    };
  };

  systemd.services.hledger-export-to-promscale = {
    description = "Export personal finance data to promscale";
    startAt = "daily";
    path = with pkgs; [ hledger ];
    serviceConfig = {
      ExecStart =
        let python = pkgs.python3.withPackages (ps: [ ps.requests ]);
        in "${python}/bin/python3 ${pkgs.writeText "hledger-export-to-promscale.py" (fileContents ./jobs/hledger-export-to-promscale.py)}";
      User = "barrucadu";
      Group = "users";
    };
    environment = {
      LEDGER_FILE = "/home/barrucadu/s/ledger/combined.journal";
      PROMSCALE_URI = "http://localhost:${toString promscalePort}";
    };
  };

  nixfiles.oci-containers.containers.promscale = {
    image = "timescale/promscale:latest";
    cmd = [ "-db.host=promscale-db" "-db.name=postgres" "-db.password=promscale" "-db.ssl-mode=allow" "-web.enable-admin-api=true" "-metrics.promql.lookback-delta=168h" ];
    dependsOn = [ "promscale-db" ];
    network = "promscale_network";
    ports = [{ host = promscalePort; inner = 9201; }];
  };
  nixfiles.oci-containers.containers.promscale-db = {
    image = "timescaledev/promscale-extension:latest-ts2-pg14";
    environment = {
      POSTGRES_PASSWORD = "promscale";
    };
    network = "promscale_network";
    volumes = [{ name = "pgdata"; inner = "/var/lib/postgresql/data"; }];
    volumeSubDir = "promscale";
  };
}
