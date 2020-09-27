{ config, pkgs, lib, ... }:

# Bring names from 'lib' into scope.
with lib;

let
  shares = [ "anime" "manga" "music" "movies" "tv" "images" "torrents" ];
in

{
  networking.hostName = "nyarlathotep";
  networking.hostId = "4a592971"; # ZFS needs one of these
  boot.supportedFilesystems = [ "zfs" ];

  services.monitoring-scripts.OnCalendar = "0/12:00:00";

  # Bootloader
  boot.loader.systemd-boot.enable = true;

  # Monthly ZFS scrub
  services.zfs.autoScrub.enable = true;
  services.zfs.autoScrub.interval = "monthly";

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "lo" "docker0" "enp4s0" ];
  networking.firewall.allowedTCPPorts = [ 8888 ]; # for testing stuff

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
  services.samba.syncPasswordsByPam = true;

  # Make / volatile
  boot.initrd.postDeviceCommands = mkAfter ''
    zfs rollback -r root/volatile/root@blank
  '';

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
    "L+ /etc/shadow - - - - /persist/etc/shadow"
  ];

  # caddy
  services.caddy.enable = true;
  services.caddy.config = ''
    http://nyarlathotep:80 {
      gzip
      root /persist/srv/http
    }

    http://bookdb.nyarlathotep:80 {
      gzip
      proxy / http://localhost:${toString config.services.bookdb.httpPort}
    }

    http://bookmarks.nyarlathotep:80 {
      gzip
      proxy / http://localhost:${toString config.services.bookmarks.httpPort}
    }

    http://flood.nyarlathotep:80 {
      gzip
      proxy / http://localhost:3001
    }

    http://finder.nyarlathotep:80 {
      gzip
      proxy / http://localhost:${toString config.services.finder.httpPort}
    }

    http://prometheus.nyarlathotep:80 {
      gzip
      proxy / http://localhost:9090
    }

    http://grafana.nyarlathotep:80 {
      gzip
      proxy / http://localhost:${toString config.services.grafana.port}
    }

    http://*:80 {
      status 421 /
    }
  '';

  # bookdb
  services.bookdb.enable = true;
  services.bookdb.image = "localhost:5000/bookdb:latest";
  services.bookdb.baseURI = "http://bookdb.nyarlathotep";
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

  # bookmarks
  services.bookmarks.enable = true;
  services.bookmarks.image = "localhost:5000/bookmarks:latest";
  services.bookmarks.baseURI = "http://bookmarks.nyarlathotep";
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

  # docker registry
  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableGarbageCollect = true;
  services.dockerRegistry.storagePath = "/persist/var/lib/docker-registry";
  virtualisation.docker.extraOptions = "--insecure-registry=localhost:5000";

  # finder
  services.finder.enable = true;
  services.finder.image = "localhost:5000/finder:latest";
  services.finder.httpPort = 3002;
  services.finder.dockerVolumeDir = /persist/docker-volumes/finder;
  services.finder.mangaDir = /mnt/nas/manga;

  # rtorrent
  systemd.services.rtorrent = {
    enable   = true;
    wantedBy = [ "default.target" ];
    after    = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.zsh}/bin/zsh --login -c \"${pkgs.tmux}/bin/tmux new-session -d -s rtorrent '${pkgs.rtorrent}/bin/rtorrent -n -O directory=/mnt/nas/torrents/files -O scgi_local=/tmp/rtorrent-rpc.socket -O session=/persist/rtorrent/session -O dht=auto -O encryption=allow_incoming,try_outgoing,require,require_RC4 -O port_random=yes -O port_range=62001-63000 -O schedule=watch.directory,5,5,load.start=/mnt/nas/torrents/watch/\\*.torrent -O check_hash=yes -O encoding_list=UTF-8'\"";
      ExecStop  = "${pkgs.zsh}/bin/zsh --login -c '${pkgs.tmux}/bin/tmux send-keys -t rtorrent C-q'";
      User      = "barrucadu";
      KillMode  = "none";
      Type      = "forking";
      Restart   = "on-failure";
    };
  };

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

  environment.systemPackages = with pkgs;
    [
      mktorrent
      nodejs-12_x
      rtorrent
      tmux
    ];

  # hledger prices
  systemd.timers.hledger-scripts = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 21:00:00";
    };
  };
  systemd.services.hledger-scripts = {
    description = "Run hledger scripts";
    serviceConfig.WorkingDirectory = "/home/barrucadu/projects/hledger-scripts";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c './sync.sh only-prices'";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };

  # monitoring / dashboards
  services.grafana = {
    enable = true;
    port = 3004;
    rootUrl = "http://grafana.nyarlathotep";
    dataDir = "/persist/var/lib/grafana";
    provision = {
      enable = true;
      datasources = [
        {
          name = "prometheus";
          url = "http://${config.services.prometheus.listenAddress}";
          type = "prometheus";
        }
      ];
      dashboards = [
        {
          name = "overview.json";
          folder = "My Dashboards";
          options.path = pkgs.writeTextDir "overview.json" (fileContents ./grafana-dashboards/overview.json);
        }
      ];
    };
  };

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1:9090";
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
    ];
    webExternalUrl = "http://prometheus.nyarlathotep";
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
}
