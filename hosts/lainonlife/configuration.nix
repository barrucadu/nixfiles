{ config, pkgs, lib, ... }:
with lib;
let
  radioUser = config.users.extraUsers.radio;

  backendPort = 8002;

  mpdService = channel: {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    description = "Music Player Daemon (channel ${channel})";
    preStart =
      let dir = "${radioUser.home}/data/${channel}";
      in "mkdir -p ${dir} && chown -R ${radioUser.name}:${radioUser.group} ${dir}";
    serviceConfig = {
      Type = "simple";
      User = radioUser.name;
      Group = radioUser.group;
      PermissionsStartOnly = true;
      ExecStart =
        let cfg = config.sops.secrets."services/mpd/${channel}".path;
        in "${pkgs.mpd}/bin/mpd --no-daemon ${cfg}";
      Restart = "on-failure";
    };
  };

  fallbackService = fmt: {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    description = "Fallback Stream (${fmt})";
    serviceConfig = {
      Type = "simple";
      User = radioUser.name;
      Group = radioUser.group;
      ExecStart =
        let cfg = config.sops.secrets."services/fallback/${fmt}".path;
        in "${pkgs.ezstream}/bin/ezstream -c ${cfg}";
      Restart = "on-failure";
    };
  };

  programmeEnv = pkgs.python3.buildEnv.override {
    extraLibs = with pkgs.python3Packages; [ docopt mpd2 ];
  };
  programmeService = channel: port: {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    description = "Radio Programming (channel ${channel})";
    startAt = "0/3:00:00";
    serviceConfig = {
      Type = "oneshot";
      User = radioUser.name;
      Group = radioUser.group;
      ExecStart = "${pkgs.python3}/bin/python3 ${radioUser.home}/scripts/schedule.py ${toString port}";
      Restart = "no";
    };
    environment = {
      PYTHONPATH = "${programmeEnv}/${pkgs.python3.sitePackages}/";
    };
  };
in
{
  networking.hostName = "lainonlife";

  sops.defaultSopsFile = ./secrets.yaml;

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  # OVH network set up
  networking.interfaces.eno1 = {
    ipv4.addresses = [{ address = "91.121.0.148"; prefixLength = 24; }];
    ipv6.addresses = [{ address = "2001:41d0:0001:5394::1"; prefixLength = 128; }];
  };

  networking.defaultGateway = "91.121.0.254";
  networking.defaultGateway6 = "2001:41d0:0001:53ff:ff:ff:ff:ff";

  networking.nameservers = [ "213.186.33.99" "2001:41d0:3:1c7::1" ];

  # Run incremental backups daily, to reduce potential pleroma data loss
  modules.backupScripts.onCalendarIncr = "*-*-* 4:00:00";

  # No syncthing
  services.syncthing.enable = mkForce false;

  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 8000 ];

  # Web server
  services.caddy.enable = true;
  services.caddy.extraConfig = ''
    (common_config) {
      encode gzip

      header Permissions-Policy "interest-cohort=()"
      header Referrer-Policy "strict-origin-when-cross-origin"
      header Strict-Transport-Security "max-age=31536000; includeSubDomains"
      header X-Content-Type-Options "nosniff"
      header X-Frame-Options "SAMEORIGIN"

      header -Server
    }

    www.lainon.life {
      import common_config
      redir https://lainon.life{uri}
    }

    lainon.life {
      import common_config

      route /radio/* {
        uri strip_prefix /radio
        reverse_proxy http://localhost:8000
      }

      route /graphs/* {
        uri strip_prefix /graphs
        reverse_proxy http://localhost:${toString config.services.grafana.port}
      }

      reverse_proxy /background http://localhost:${toString backendPort}
      reverse_proxy /playlist/* http://localhost:${toString backendPort}

      file_server {
        root /srv/http/www
      }
    }

    ${config.services.pleroma.domain} {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.services.pleroma.httpPort}
    }
  '';

  systemd.services.http-backend = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    description = "HTTP backend service";
    serviceConfig = {
      Type = "simple";
      User = radioUser.name;
      Group = radioUser.group;
      ExecStart = "${pkgs.bash}/bin/bash -l -c ${radioUser.home}/backend/run.sh";
    };
    environment = {
      CONFIG = "${radioUser.home}/config.json";
      PORT = toString backendPort;
      ICECAST = "http://localhost:8000";
      PROMETHEUS = "http://localhost:${toString config.services.prometheus.port}";
    };
  };

  services.logrotate.enable = true;
  services.logrotate.settings.icecast = {
    files = [ "/var/log/icecast/access.log" "/var/log/icecast/error.log" ];
    frequency = "daily";
    copytruncate = true;
    rotate = 1;
    compress = true;
    postrotate = "systemctl kill icecast.service --signal=HUP";
  };

  # Radio
  users.extraUsers.radio = {
    home = "/srv/radio";
    group = "audio";
    isSystemUser = true;
    description = "Music Player Daemon user";
    shell = "${pkgs.bash}/bin/bash";
  };

  ## Icecast
  systemd.services.icecast = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    description = "Icecast Network Audio Streaming Server";
    preStart = "mkdir -p /var/log/icecast && chown nobody:nogroup /var/log/icecast";
    serviceConfig = {
      Type = "simple";
      User = radioUser.name;
      Group = radioUser.group;
      PermissionsStartOnly = true;
      ExecStart = "${pkgs.icecast}/bin/icecast -c ${config.sops.secrets."services/icecast".path}";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      BindPaths = "${pkgs.icecast}/share/icecast:/icecast";
    };
  };

  sops.secrets."services/icecast".owner = radioUser.name;

  ## MPD
  systemd.services.mpd-everything = mpdService "everything";
  systemd.services.mpd-cyberia = mpdService "cyberia";
  systemd.services.mpd-swing = mpdService "swing";
  systemd.services.mpd-cafe = mpdService "cafe";

  systemd.services.programme-everything = programmeService "everything" 6600;
  systemd.services.programme-cyberia = programmeService "cyberia" 6601;
  systemd.services.programme-swing = programmeService "swing" 6602;
  systemd.services.programme-cafe = programmeService "cafe" 6603;

  sops.secrets."services/mpd/everything".owner = radioUser.name;
  sops.secrets."services/mpd/cyberia".owner = radioUser.name;
  sops.secrets."services/mpd/swing".owner = radioUser.name;
  sops.secrets."services/mpd/cafe".owner = radioUser.name;

  nixpkgs.config.packageOverrides = pkgs: {
    # Build MPD with libmp3lame support, so shoutcast output can do mp3.
    mpd = pkgs.mpd.overrideAttrs (oldAttrs: rec {
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.lame ];
    });
  };

  ## Fallback
  systemd.services.fallback-mp3 = fallbackService "mp3";
  systemd.services.fallback-ogg = fallbackService "ogg";

  sops.secrets."services/fallback/mp3".owner = radioUser.name;
  sops.secrets."services/fallback/ogg".owner = radioUser.name;

  # Pleroma
  services.pleroma.enable = true;
  services.pleroma.image = "registry.barrucadu.dev/pleroma:latest";
  services.pleroma.pullOnStart = true;
  services.pleroma.registry = {
    username = "registry";
    passwordFile = config.sops.secrets."services/pleroma/docker_registry".path;
    url = "https://registry.barrucadu.dev";
  };
  services.pleroma.domain = "social.lainon.life";
  services.pleroma.faviconPath = ./pleroma-favicon.png;
  services.pleroma.dockerVolumeDir = "/persist/docker-volumes/pleroma";
  services.pleroma.secretsFile = config.sops.secrets."services/pleroma/exc".path;
  # TODO: figure out how to lock this down so only the pleroma process
  # can read it (remap the container UID / GID to something known,
  # perhaps?)
  sops.secrets."services/pleroma/exc".mode = "0444";
  sops.secrets."services/pleroma/docker_registry" = { };

  # Fancy graphs
  services.grafana = {
    enable = true;
    port = 8001;
    domain = "lainon.life";
    rootUrl = "https://lainon.life/graphs/";
    security.adminPasswordFile = config.sops.secrets."services/grafana/admin_password".path;
    security.secretKeyFile = config.sops.secrets."services/grafana/secret_key".path;

    auth.anonymous.enable = true;
    auth.anonymous.org_name = "lainon.life";
    provision = {
      enable = true;
      datasources = [
        {
          name = "prometheus";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          type = "prometheus";
        }
      ];
      dashboards = [
        {
          name = "lainon.life";
          options.path = pkgs.writeTextDir "lainon.life" (fileContents ./grafana-dashboards/main.json);
        }
      ];
    };
  };
  sops.secrets."services/grafana/admin_password".owner = config.users.users.grafana.name;
  sops.secrets."services/grafana/secret_key".owner = config.users.users.grafana.name;
  services.prometheus.scrapeConfigs = [
    {
      job_name = "radio";
      static_configs = [{ targets = [ "localhost:${toString backendPort}" ]; }];
    }
  ];

  # barrucadu.dev concourse access
  security.sudo.extraRules = [
    {
      users = [ "concourse-deploy-robot" ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl restart docker-pleroma"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];
  users.extraUsers.concourse-deploy-robot = {
    home = "/home/system/concourse-deploy-robot";
    createHome = true;
    isSystemUser = true;
    openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGuk+GIuV7G26dr3EEVlEX6YGKonb3Huiha24gF8DuFP concourse-worker@cd.barrucadu.dev" ];
    shell = pkgs.bashInteractive;
    group = "nogroup";
  };

  # Extra users
  users.extraUsers.appleman1234 = {
    uid = 1001;
    description = "Appleman1234 <admin@lainchan.org>";
    isNormalUser = true;
    group = "users";
  };
  users.extraUsers.yuuko = {
    uid = 1002;
    description = "Yuuko";
    isNormalUser = true;
    group = "users";
    extraGroups = [ "audio" ];
  };

  # Misc
  environment.systemPackages = with pkgs; [ flac id3v2 ncmpcpp openssl python3Packages.virtualenv ];
}
