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
    ];
  environment.systemPackages = with pkgs; [ flac id3v2 ncmpcpp python35Packages.virtualenv ];

  nixpkgs.config.packageOverrides = pkgs: {
    # Build MPD with libmp3lame support, so shoutcast output can do mp3.
    mpd = pkgs.mpd.overrideAttrs (oldAttrs: rec {
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.lame ];
    });

    # Set up the Python 3 environment we want for the systemd services.
    python3 = pkgs.python35.withPackages (p: [p.docopt p.influxdb p.mpd2 p.psutil p.requests]);

    # Ezstream, for the fallback streams.
    ezstream = pkgs.callPackage
      ( { stdenv, fetchurl, libiconv, libshout, taglib, libxml2, pkgconfig }:
        stdenv.mkDerivation rec {
          name = "ezstream-${version}";
          version = "0.6.0";

          src = fetchurl {
            url = "https://ftp.osuosl.org/pub/xiph/releases/ezstream/${name}.tar.gz";
            sha256 = "f86eb8163b470c3acbc182b42406f08313f85187bd9017afb8b79b02f03635c9";
          };

          buildInputs = [ libiconv libshout taglib libxml2 ];
          nativeBuildInputs = [ pkgconfig ];

          doCheck = true;

          meta = with pkgs.stdenv.lib; {
            description = "A command line source client for Icecast media streaming servers";
            license = licenses.gpl2;
          };
        }
       ) {};
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
