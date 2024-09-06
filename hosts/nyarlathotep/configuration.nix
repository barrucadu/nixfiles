# This is my home server.
#
# It runs writable instances of the bookdb and bookmarks services, which have
# any updates copied across to carcosa hourly; it acts as a NAS; and it runs a
# few utility services.
#
# Like carcosa, this host is set up in "erase your darlings" style but, unlike
# carcosa, it automatically reboots to install updates: so that takes effect
# significantly more frequently.
#
# **Alerting:** enabled (standard only)
#
# **Backups:** enabled (standard + extras)
#
# **Public hostname:** n/a
#
# **Role:** server
{ config, pkgs, lib, ... }:

# Bring names from 'lib' into scope.
with lib;
let
  shares = [ "anime" "manga" "misc" "music" "movies" "tv" "torrents" ];

  promscalePort = 9201;
  prometheusAwairExporterPort = 9517;

  httpdir = "${toString config.nixfiles.eraseYourDarlings.persistDir}/srv/http";
in
{
  ###############################################################################
  ## General
  ###############################################################################

  networking.hostId = "4a592971"; # ZFS needs one of these
  boot.supportedFilesystems = { zfs = true; };

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
  ];

  # Wipe / on boot
  nixfiles.eraseYourDarlings.enable = true;
  nixfiles.eraseYourDarlings.machineId = "0f7ae3bda2a9428ab77a0adddc4c8cff";
  nixfiles.eraseYourDarlings.barrucaduPasswordFile = config.sops.secrets."users/barrucadu".path;
  sops.secrets."users/barrucadu".neededForUsers = true;

  # Set up a bridge network so that VMs can connect to the LAN
  #
  # `enp8s0` is the physical ethernet interface, but I am slaving that to the
  # `br0` bridge - so it's the bridge's MAC address that gets presented to the
  # physical network.
  #
  # To avoid having to reconfigure static IP assignments in my router if I
  # switch between bridged and non-bridged networking, set up the MAC addresses
  # such that:
  #
  # - `br0` has the MAC address of the physical ethernet card
  # - `enp8s0` has a new random MAC address (https://serverfault.com/a/631119)
  #
  # So if I delete this block, the MAC address the router sees is unchanged, and
  # so the static IP assignment is unaffected.
  networking.useDHCP = false;
  networking.interfaces.br0 = {
    useDHCP = true;
    macAddress = "a0:36:bc:bb:65:8d";
  };
  networking.interfaces.enp8s0 = {
    macAddress = "92:0b:e6:21:86:99";
    useDHCP = true;
  };
  networking.bridges.br0.interfaces = [ "enp8s0" ];

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.allowedBridges = [ "br0" ];

  ###############################################################################
  ## Backups
  ###############################################################################

  nixfiles.restic-backups.enable = true;
  nixfiles.restic-backups.environmentFile = config.sops.secrets."nixfiles/restic-backups/env".path;
  nixfiles.restic-backups.backups.torrents = {
    prepareCommand = ''
      ${pkgs.python3}/bin/python3 ${./jobs/restic-prepare--hardlink-torrent-files.py} > hardlink-torrent-files.sh
    '';
    paths = [
      "hardlink-torrent-files.sh"
      "/mnt/nas/torrents/watch"
    ];
  };
  nixfiles.restic-backups.backups.youtube = {
    prepareCommand = ''
      ${pkgs.python3}/bin/python3 ${./jobs/restic-prepare--fetch-youtube.py} > fetch-youtube.sh
    '';
    paths = [
      "fetch-youtube.sh"
    ];
  };
  sops.secrets."nixfiles/restic-backups/env" = { };


  ###############################################################################
  ## DNS
  ###############################################################################

  nixfiles.resolved.enable = true;
  nixfiles.resolved.address = "10.0.0.3:53";
  nixfiles.resolved.cacheSize = 1000000;
  nixfiles.resolved.hostsDirs = [ "/etc/dns/hosts" ];
  nixfiles.resolved.zonesDirs = [ "/etc/dns/zones" ];

  environment.etc."dns/hosts/stevenblack".source =
    let commit = "14b698abcd97446bae349292aacc9ecb4feb2db5";
    in builtins.fetchurl {
      url = "https://raw.githubusercontent.com/StevenBlack/hosts/${commit}/hosts";
      sha256 = "1hwyn1w1c7brzigp7fqpsgh107pzvsrahilq6n90jw7yzvi704gl";
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
    hashedPasswordFile = config.sops.secrets."users/notbarrucadu".path;
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
  '';

  services.caddy.virtualHosts."nyarlathotep.lan:80".extraConfig = ''
    import restrict_vlan
    encode gzip
    file_server {
      root ${httpdir}/nyarlathotep.lan
    }
  '';

  services.caddy.virtualHosts."alertmanager.nyarlathotep.lan:80".extraConfig = ''
    import restrict_vlan
    encode gzip
    reverse_proxy http://localhost:${toString config.services.prometheus.alertmanager.port}
  '';

  services.caddy.virtualHosts."bookdb.nyarlathotep.lan:80".extraConfig = ''
    import restrict_vlan
    encode gzip
    reverse_proxy http://localhost:${toString config.nixfiles.bookdb.port}
  '';

  services.caddy.virtualHosts."bookmarks.nyarlathotep.lan:80".extraConfig = ''
    import restrict_vlan
    encode gzip
    reverse_proxy http://localhost:${toString config.nixfiles.bookmarks.port}
  '';

  services.caddy.virtualHosts."flood.nyarlathotep.lan:80".extraConfig = ''
    import restrict_vlan
    encode gzip
    reverse_proxy http://localhost:${toString config.nixfiles.torrents.rpcPort}
  '';

  services.caddy.virtualHosts."finder.nyarlathotep.lan:80".extraConfig = ''
    import restrict_vlan
    encode gzip
    reverse_proxy http://localhost:${toString config.nixfiles.finder.port}
  '';

  services.caddy.virtualHosts."grafana.nyarlathotep.lan:80".extraConfig = ''
    import restrict_vlan
    encode gzip
    reverse_proxy http://localhost:${toString config.services.grafana.settings.server.http_port}
  '';

  services.caddy.virtualHosts."rpg-tools.nyarlathotep.lan:80".extraConfig = ''
    import restrict_vlan
    encode gzip
    file_server {
      root ${httpdir}/rpg-tools.nyarlathotep.lan
    }
  '';

  services.caddy.virtualHosts."prometheus.nyarlathotep.lan:80".extraConfig = ''
    import restrict_vlan
    encode gzip
    reverse_proxy http://localhost:${toString config.services.prometheus.port}
  '';

  services.caddy.virtualHosts."help.lan:80".extraConfig = ''
    import vlan_matchers
    redir @vlan1 http://vlan1.help.lan 302
    redir @vlan10 http://vlan10.help.lan 302
    redir @vlan20 http://vlan20.help.lan 302
  '';

  services.caddy.virtualHosts."vlan1.help.lan:80".extraConfig = ''
    import vlan_matchers
    encode gzip
    redir @not_vlan1 http://help.lan 302
    file_server {
      root ${httpdir}/vlan1.help.lan
    }
  '';

  services.caddy.virtualHosts."vlan10.help.lan:80".extraConfig = ''
    import vlan_matchers
    encode gzip
    redir @not_vlan10 http://help.lan 302
    file_server {
      root ${httpdir}/vlan10.help.lan
    }
  '';

  services.caddy.virtualHosts."vlan20.help.lan:80".extraConfig = ''
    import vlan_matchers
    encode gzip
    redir @not_vlan20 http://help.lan 302
    file_server {
      root ${httpdir}/vlan20.help.lan
    }
  '';

  services.caddy.virtualHosts."*:80".extraConfig = ''
    respond * 421
  '';


  ###############################################################################
  ## bookdb - https://github.com/barrucadu/bookdb
  ###############################################################################

  nixfiles.bookdb.enable = true;


  ###############################################################################
  ## bookmarks - https://github.com/barrucadu/bookmarks
  ###############################################################################

  nixfiles.bookmarks.enable = true;


  ###############################################################################
  ## finder
  ###############################################################################

  nixfiles.finder.enable = true;
  nixfiles.finder.image = "localhost:${toString config.services.dockerRegistry.port}/finder:latest";
  nixfiles.finder.mangaDir = "/mnt/nas/manga";


  ###############################################################################
  ## torrents
  ###############################################################################

  nixfiles.torrents.enable = true;
  nixfiles.torrents.downloadDir = "/mnt/nas/torrents/files";
  nixfiles.torrents.watchDir = "/mnt/nas/torrents/watch";
  nixfiles.torrents.user = "barrucadu";
  nixfiles.torrents.group = "users";


  ###############################################################################
  # Monitoring & Dashboards
  ###############################################################################

  services.prometheus.alertmanager.environmentFile = config.sops.secrets."services/alertmanager/env".path;
  sops.secrets."services/alertmanager/env" = { };

  services.grafana = {
    settings.server.root_url = "http://grafana.nyarlathotep.lan";
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
      wants = [ "network-online.target" ];
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
  virtualisation.containers.registries.insecure = [ "localhost:${toString config.services.dockerRegistry.port}" ];


  ###############################################################################
  # Automatic music tagging
  ###############################################################################

  systemd.services.tag-podcasts = {
    enable = true;
    description = "Automatically tag new podcast files";
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ ffmpeg inotifyTools id3v2 ];
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

  nixfiles.oci-containers.pods.promscale = {
    containers = {
      web = {
        image = "timescale/promscale:latest";
        cmd = [
          "-db.host=promscale-db"
          "-db.name=postgres"
          "-db.password=promscale"
          "-db.ssl-mode=allow"
          "-web.enable-admin-api=true"
          "-metrics.promql.lookback-delta=168h"
        ];
        dependsOn = [ "promscale-db" ];
        ports = [{ host = promscalePort; inner = 9201; }];
      };
      db = {
        image = "timescaledev/promscale-extension:latest-ts2-pg14";
        environment = {
          POSTGRES_PASSWORD = "promscale";
        };
        volumes = [{ name = "pgdata"; inner = "/var/lib/postgresql/data"; }];
      };
    };
  };


  ###############################################################################
  # Remote Sync
  ###############################################################################

  users.extraUsers.remote-sync = {
    home = "/var/lib/remote-sync";
    createHome = true;
    isSystemUser = true;
    shell = pkgs.bashInteractive;
    group = "nogroup";
  };

  systemd.services.bookdb-sync = {
    description = "Upload bookdb data to carcosa";
    startAt = "*:15";
    path = with pkgs; [ openssh rsync ];
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "bookdb-sync" ''
        set -ex

        /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cp -r ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR}/ ~/bookdb-covers
        trap "/run/wrappers/bin/sudo ${pkgs.coreutils}/bin/rm -rf ~/bookdb-covers" EXIT
        rsync -az\
              -e "ssh -i $SSH_KEY_FILE -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
              ~/bookdb-covers/ \
              nyarlathotep-remote-sync@carcosa.barrucadu.co.uk:~/bookdb-covers/
        ssh -i "$SSH_KEY_FILE" \
            -o UserKnownHostsFile=/dev/null \
            -o StrictHostKeyChecking=no \
            nyarlathotep-remote-sync@carcosa.barrucadu.co.uk \
            bookdb-receive-covers

        env "ES_HOST=$ES_HOST" \
            ${pkgs.nixfiles.bookdb}/bin/bookdb_ctl export-index | \
        ssh -i "$SSH_KEY_FILE" \
            -o UserKnownHostsFile=/dev/null \
            -o StrictHostKeyChecking=no \
            nyarlathotep-remote-sync@carcosa.barrucadu.co.uk \
            bookdb-receive-elasticsearch
      '';
      User = config.users.extraUsers.remote-sync.name;
    };
    environment = {
      ES_HOST = config.systemd.services.bookdb.environment.ES_HOST;
      SSH_KEY_FILE = config.sops.secrets."users/remote_sync/ssh_private_key".path;
    };
  };

  systemd.services.bookmarks-sync = {
    description = "Upload bookmarks data to carcosa";
    startAt = "*:15";
    path = with pkgs; [ openssh ];
    serviceConfig = {
      ExecStart = pkgs.writeShellScript "bookmarks-sync" ''
        set -ex

        env "ES_HOST=$ES_HOST" \
            ${pkgs.nixfiles.bookmarks}/bin/bookmarks_ctl export-index | \
        ssh -i "$SSH_KEY_FILE" \
            -o UserKnownHostsFile=/dev/null \
            -o StrictHostKeyChecking=no \
            nyarlathotep-remote-sync@carcosa.barrucadu.co.uk \
            bookmarks-receive-elasticsearch
      '';
      User = config.users.extraUsers.remote-sync.name;
    };
    environment = {
      ES_HOST = config.systemd.services.bookmarks.environment.ES_HOST;
      SSH_KEY_FILE = config.sops.secrets."users/remote_sync/ssh_private_key".path;
    };
  };

  security.sudo.extraRules = [
    {
      users = [ config.users.extraUsers.remote-sync.name ];
      commands = [
        { command = "${pkgs.coreutils}/bin/cp -r ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR}/ ${config.users.extraUsers.remote-sync.home}/bookdb-covers"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.coreutils}/bin/rm -rf ${config.users.extraUsers.remote-sync.home}/bookdb-covers"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  sops.secrets."users/remote_sync/ssh_private_key".owner = config.users.extraUsers.remote-sync.name;

  ###############################################################################
  # RSS-to-Mastodon
  ###############################################################################

  users.extraUsers.rss-to-mastodon = {
    home = "/persist/var/lib/rss-to-mastodon";
    createHome = true;
    isSystemUser = true;
    group = "nogroup";
  };

  systemd.services.rss-to-mastodon-kjp-hacksrus = {
    description = "Publish King James Programming to hacksrus.xyz";
    startAt = "hourly";
    serviceConfig = {
      ExecStart =
        let python = pkgs.python3.withPackages (ps: [ ps.beautifulsoup4 ps.docopt ps.feedparser ps.requests ]);
        in concatStringsSep " " [
          "${python}/bin/python3"
          (pkgs.writeText "rss-to-mastodon.py" (fileContents ./jobs/rss-to-mastodon.py))
          "--use-summary"
          "-d https://hacksrus.xyz/"
          "-f https://kingjamesprogramming.tumblr.com/rss"
          "-l /persist/var/lib/rss-to-mastodon/kjp-hacksrus.txt"
        ];
      User = "rss-to-mastodon";
      EnvironmentFile = config.sops.secrets."users/rss_to_mastodon/kjp_hacksrus_env".path;
    };
  };

  sops.secrets."users/rss_to_mastodon/kjp_hacksrus_env" = { };
}
