{ config, pkgs, lib, ... }:
with lib;
let
  radio = import ./service-radio.nix { inherit lib pkgs; };

  radioChannels = [
    {
      channel = "everything";
      port = 6600;
      description = "all the music, all the time";
      mpdPassword = fileContents /etc/nixos/secrets/everything-password-mpd.txt;
      livePassword = fileContents /etc/nixos/secrets/everything-password-live.txt;
    }
    {
      channel = "cyberia";
      port = 6601;
      description = "classic lainchan radio: electronic, chiptune, weeb";
      mpdPassword = fileContents /etc/nixos/secrets/cyberia-password-mpd.txt;
      livePassword = fileContents /etc/nixos/secrets/cyberia-password-live.txt;
    }
    {
      channel = "swing";
      port = 6602;
      description = "swing, electroswing, and jazz";
      mpdPassword = fileContents /etc/nixos/secrets/swing-password-mpd.txt;
      livePassword = fileContents /etc/nixos/secrets/swing-password-live.txt;
    }
    {
      channel = "cafe";
      port = 6603;
      description = "music to drink tea to";
      mpdPassword = fileContents /etc/nixos/secrets/cafe-password-mpd.txt;
      livePassword = fileContents /etc/nixos/secrets/cafe-password-live.txt;
    }
  ];

  backendPort = 8002;

  pullDevDockerImage = pkgs.writeShellScript "pull-dev-docker-image.sh" ''
    set -e
    set -o pipefail

    ${pkgs.coreutils}/bin/cat /etc/nixos/secrets/registry-password.txt | ${pkgs.docker}/bin/docker login --username registry --password-stdin https://registry.barrucadu.dev
    ${pkgs.docker}/bin/docker pull registry.barrucadu.dev/$1
  '';
in
{
  networking.hostName = "lainonlife";

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
  networking.firewall.allowedTCPPortRanges = [{ from = 62001; to = 63000; }];
  networking.firewall.allowedUDPPortRanges = [{ from = 62001; to = 63000; }];

  # Web server
  services.caddy.enable = true;
  services.caddy.config = ''
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
        reverse_proxy http://localhost:${toString config.services.icecast.listen.port}
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

  services.logrotate.enable = true;
  services.logrotate.config = ''
    /var/log/icecast/access.log /var/log/icecast/error.log {
        daily
        copytruncate
        rotate 1
        compress
        postrotate
            systemctl kill icecast.service --signal=HUP
        endscript
    }
  '';

  # Radio
  users.extraUsers."${radio.username}" = radio.userSettings;
  services.icecast = radio.icecastSettingsFor radioChannels;
  systemd.services =
    let service = { user, description, execstart, environment ? { }, ... }: {
      inherit environment description;
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = { User = user; ExecStart = execstart; Restart = "on-failure"; };
    };
    in
    mkMerge
      [
        (listToAttrs (map (c@{ channel, ... }: nameValuePair "mpd-${channel}" (radio.mpdServiceFor c)) radioChannels))
        (listToAttrs (map (c@{ channel, ... }: nameValuePair "programme-${channel}" (radio.programmingServiceFor c)) radioChannels))

        { fallback-mp3 = radio.fallbackServiceForMP3 "/srv/radio/music/fallback.mp3"; }
        { fallback-ogg = radio.fallbackServiceForOgg "/srv/radio/music/fallback.ogg"; }

        {
          "http-backend" = service {
            user = "${radio.username}";
            description = "HTTP backend service";
            execstart = "${pkgs.bash}/bin/bash -l -c /srv/radio/backend/run.sh";
            environment = {
              CONFIG = "/srv/radio/config.json";
              PORT = toString backendPort;
              ICECAST = "http://localhost:${toString config.services.icecast.listen.port}";
              PROMETHEUS = "http://localhost:${toString config.services.prometheus.port}";
            };
          };
        }
      ];

  environment.systemPackages = with pkgs; [ flac id3v2 ncmpcpp openssl python3Packages.virtualenv ];

  nixpkgs.config.packageOverrides = pkgs: {
    # Build MPD with libmp3lame support, so shoutcast output can do mp3.
    mpd = pkgs.mpd.overrideAttrs (oldAttrs: rec {
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.lame ];
    });
  };

  # Pleroma
  services.pleroma.enable = true;
  services.pleroma.image = "registry.barrucadu.dev/pleroma:latest";
  services.pleroma.domain = "social.lainon.life";
  services.pleroma.secretKeyBase = fileContents /etc/nixos/secrets/pleroma/secret-key-base.txt;
  services.pleroma.signingSalt = fileContents /etc/nixos/secrets/pleroma/signing-salt.txt;
  services.pleroma.webPushPublicKey = fileContents /etc/nixos/secrets/pleroma/web-push-public-key.txt;
  services.pleroma.webPushPrivateKey = fileContents /etc/nixos/secrets/pleroma/web-push-private-key.txt;
  services.pleroma.execStartPre = "${pullDevDockerImage} pleroma:latest";
  services.pleroma.faviconPath = /etc/nixos/files/pleroma-favicon.png;
  services.pleroma.dockerVolumeDir = "/persist/docker-volumes/pleroma";

  # Fancy graphs
  services.grafana = {
    enable = true;
    port = 8001;
    domain = "lainon.life";
    rootUrl = "https://lainon.life/graphs/";
    security.adminPassword = fileContents /etc/nixos/secrets/grafana-admin-password.txt;
    security.secretKey = fileContents /etc/nixos/secrets/grafana-key.txt;
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
}
