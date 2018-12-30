{ config, pkgs, lib, ... }:

let
  radio = import ./hosts/lainonlife/radio.nix { inherit lib pkgs; };

  radioChannels = [
    { channel = "everything"; port = 6600; description = "all the music, all the time"
    ; mpdPassword  = import /etc/nixos/secrets/everything-password-mpd.nix
    ; livePassword = import /etc/nixos/secrets/everything-password-live.nix
    ; }
    { channel = "cyberia"; port = 6601; description = "classic lainchan radio: electronic, chiptune, weeb"
    ; mpdPassword  = import /etc/nixos/secrets/cyberia-password-mpd.nix
    ; livePassword = import /etc/nixos/secrets/cyberia-password-live.nix
    ; }
    { channel = "swing"; port = 6602; description = "swing, electroswing, and jazz"
    ; mpdPassword  = import /etc/nixos/secrets/swing-password-mpd.nix
    ; livePassword = import /etc/nixos/secrets/swing-password-live.nix
    ; }
    { channel = "cafe"; port = 6603; description = "music to drink tea to"
    ; mpdPassword  = import /etc/nixos/secrets/cafe-password-mpd.nix
    ; livePassword = import /etc/nixos/secrets/cafe-password-live.nix
    ; }
  ];
in

{
  networking.hostName = "lainonlife";

  imports = [
    ./common.nix
    ./hardware-configuration.nix
    ./services/nginx.nix
    ./services/rtorrent.nix
  ];

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # OVH network set up
  networking.interfaces.eno1 = {
    ipv4.addresses = [ { address = "91.121.0.148";           prefixLength = 24;  } ];
    ipv6.addresses = [ { address = "2001:41d0:0001:5394::1"; prefixLength = 128; } ];
  };

  networking.defaultGateway  = "91.121.0.254";
  networking.defaultGateway6 = "2001:41d0:0001:53ff:ff:ff:ff:ff";

  networking.nameservers = [ "213.186.33.99" "2001:41d0:3:1c7::1" ];

  # No syncthing
  services.syncthing.enable = lib.mkForce false;

  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 8000 ];
  networking.firewall.allowedTCPPortRanges = [ { from = 60000; to = 63000; } ];
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 63000; } ];

  # Web server
  services.nginx.virtualHosts."lainon.life" = {
    serverAliases = [ "www.lainon.life" ];
    enableACME = true;
    forceSSL = true;
    default = true;
    root = "/srv/http";
    locations."/".extraConfig = "try_files $uri $uri/ @script;";
    locations."/radio/".proxyPass  = "http://localhost:8000/";
    locations."/graphs/".proxyPass = "http://localhost:8001/";
    locations."@script".proxyPass = "http://localhost:8002";
  };

  services.logrotate.enable = true;
  services.logrotate.config = ''
/var/spool/nginx/logs/access.log /var/spool/nginx/logs/error.log {
    daily
    copytruncate
    rotate 1
    compress
    postrotate
        systemctl kill nginx.service --signal=USR1
    endscript
}
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
    let service = {user, description, execstart, ...}: {
          after         = [ "network.target" ];
          description   = description;
          wantedBy      = [ "multi-user.target" ];
          serviceConfig = { User = user; ExecStart = execstart; Restart = "on-failure"; };
        };
    in lib.mkMerge
      [ (lib.listToAttrs (map (c@{channel, ...}: lib.nameValuePair "mpd-${channel}"       (radio.mpdServiceFor         c)) radioChannels))
        (lib.listToAttrs (map (c@{channel, ...}: lib.nameValuePair "programme-${channel}" (radio.programmingServiceFor c)) radioChannels))

      { fallback-mp3 = radio.fallbackServiceForMP3 "/srv/radio/music/fallback.mp3"; }
      { fallback-ogg = radio.fallbackServiceForOgg "/srv/radio/music/fallback.ogg"; }

      # Because I am defining systemd.services in its entirety here, all services defined in this
      # file need to live in this list too.
      { metrics = service {
          # This needs to run as root so that `du` can measure everything.
          user = "root";
          description = "Report metrics";
          execstart = "${pkgs.python3}/bin/python3 /srv/radio/scripts/metrics.py";
        };
      }

      { "http-backend" = service {
          user = config.services.nginx.user;
          description = "HTTP backend service";
          execstart = "${pkgs.bash}/bin/bash -l -c '/srv/radio/backend/run.sh serve --config=/srv/radio/config.json 8002'";
        };
      }

    { "pleroma" = {
        after         = [ "network.target" "postgresql.service" ];
        description   = "Pleroma social network";
        wantedBy      = [ "multi-user.target" ];
        path          = with pkgs; [ elixir git openssl ];
        environment   = {
          HOME    = config.users.extraUsers.pleroma.home;
          MIX_ENV = "prod";
        };
        serviceConfig = {
          WorkingDirectory = "${config.users.extraUsers.pleroma.home}/pleroma";
          User       = "pleroma";
          ExecStart  = "${pkgs.elixir}/bin/mix phx.server";
          ExecReload = "${pkgs.coreutils}/bin/kill $MAINPID";
          KillMode   = "process";
          Restart    = "on-failure";
        };
      };
    }
    ];
  environment.systemPackages = with pkgs; [ elixir erlang flac id3v2 ncmpcpp openssl python35Packages.virtualenv ];

  nixpkgs.config.packageOverrides = pkgs: {
    # Build MPD with libmp3lame support, so shoutcast output can do mp3.
    mpd = pkgs.mpd.overrideAttrs (oldAttrs: rec {
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.lame ];
    });

    # Set up the Python 3 environment we want for the systemd services.
    python3 = pkgs.python3.withPackages (p: [p.docopt p.influxdb p.mpd2 p.psutil p.requests]);
  };

  # Pleroma
  services.postgresql.enable = true;
  services.postgresql.package = pkgs.postgresql96;

  services.nginx.virtualHosts."social.lainon.life" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:4000/";
      proxyWebsockets = true;
      # https://git.pleroma.social/pleroma/pleroma/blob/develop/installation/pleroma.nginx
      extraConfig = ''
        header_filter_by_lua_block {
          ngx.header["Access-Control-Allow-Methods"] = "POST, PUT, DELETE, GET, PATCH, OPTIONS"
          ngx.header["Access-Control-Allow-Headers"] = "Authorization, Content-Type, Idempotency-Key"
          ngx.header["Access-Control-Expose-Headers"] = "Link, X-RateLimit-Reset, X-RateLimit-Limit, X-RateLimit-Remaining, X-Request-Id"
          ngx.header["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' http: https: data:; connect-src 'self' wss://social.lainon.life/"
          ngx.header["X-Download-Options"] = "noopen"
          ngx.header["Content-Security-Policy"] = "default-src 'none'; base-uri 'self'; form-action *; frame-ancestors 'none'; img-src 'self' data: https:; media-src 'self' https:; style-src 'self' 'unsafe-inline'; font-src 'self'; script-src 'self'; connect-src 'self' wss://social.lainon.life; upgrade-insecure-requests;"
        }

        if ($request_method = OPTIONS) {
          return 204;
        }
      '';
    };
    locations."/proxy".proxyPass = "http://localhost:4000/";
  };

  users.extraUsers.pleroma = {
    home = "/srv/pleroma";
    createHome = true;
    isSystemUser = true;
  };

  # Fancy graphs
  services.grafana = {
    enable = true;
    port = 8001;
    domain = "lainon.life";
    rootUrl = "https://lainon.life/graphs/";
    security.adminPassword = import /etc/nixos/secrets/grafana-admin-password.nix;
    security.secretKey = import /etc/nixos/secrets/grafana-key.nix;
    auth.anonymous.enable = true;
    auth.anonymous.org_name = "lainon.life";
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
