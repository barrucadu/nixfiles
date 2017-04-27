{ config, pkgs, lib, ... }:

let
  radio = import ./hosts/lainonlife/radio.nix { inherit pkgs; };

  radioChannels = [
    { channel = "everything"; port = 6600; description = "all the music, all the time"; }
    { channel = "cyberia";    port = 6601; description = "classic lainchan radio: electronic, chiptune, weeb"; }
    { channel = "swing";      port = 6602; description = "swing, electroswing, and jazz"; }
  ];
in

{
  networking.hostName = "lainonlife";

  imports = [
    ./common.nix
    ./hardware-configuration.nix
  ];

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # OVH network set up
  networking.interfaces.eno1 = {
    ip4 = [ { address = "91.121.0.148";           prefixLength = 24;  } ];
    ip6 = [ { address = "2001:41d0:0001:5394::1"; prefixLength = 128; } ];
  };

  networking.defaultGateway  = "91.121.0.254";
  networking.defaultGateway6 = "2001:41d0:0001:53ff:ff:ff:ff:ff";

  networking.nameservers = [ "213.186.33.99" "2001:41d0:3:1c7::1" ];

  # No syncthing
  services.syncthing.enable = lib.mkForce false;

  # Firewall
  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [ 80 443 8000 ];
  networking.firewall.allowedTCPPortRanges = [ { from = 60000; to = 63000; } ];
  networking.firewall.allowedUDPPortRanges = [ { from = 60000; to = 63000; } ];

  # Web server
  services.nginx.enable = true;
  services.nginx.recommendedGzipSettings  = true;
  services.nginx.recommendedOptimisation  = true;
  services.nginx.recommendedProxySettings = true;
  services.nginx.recommendedTlsSettings   = true;
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
    extraConfig = "add_header 'Access-Control-Allow-Origin' '*';";
  };

  services.logrotate.enable = true;
  services.logrotate.config = ''
/var/spool/nginx/logs/access.log /var/spool/nginx/logs/error.log {
    weekly
    copytruncate
    rotate 4
    compress
    postrotate
        systemctl kill nginx.service --signal=USR1
    endscript
}
  '';

  # Radio
  users.extraUsers."${radio.username}" = radio.userSettings;
  services.icecast = radio.icecastSettings;
  systemd.services = lib.mkMerge
    [ (lib.listToAttrs (map (c@{channel, ...}: lib.nameValuePair "mpd-${channel}"       (radio.mpdServiceFor         c)) radioChannels))
      (lib.listToAttrs (map (c@{channel, ...}: lib.nameValuePair "programme-${channel}" (radio.programmingServiceFor c)) radioChannels))

      # Because I am defining systemd.services in its entirety here, all services defined in this
      # file need to live in this list too.
      { metrics = {
          after = [ "network.target" ];
          description = "Report metrics";
          wantedBy = [ "multi-user.target" ];
          startAt = "*:*:0,30";

          serviceConfig = {
            User = radio.username;
            ExecStart = "${pkgs.bash}/bin/bash -l -c \"${pkgs.nix}/bin/nix-shell -p python3Packages.influxdb python3Packages.psutil --run /srv/http/misc/metrics.py\"";
            Type = "oneshot";
          };
        };
      }

      { "http-backend" = {
          after = [ "network.target" ];
          description = "HTTP backend service";
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            User = config.services.nginx.user;
            ExecStart = "${pkgs.bash}/bin/bash -l -c \"${pkgs.nix}/bin/nix-shell -p python3Packages.flask --run '/srv/http/misc/backend.py 8002'\"";
          };
        };
      }
    ];
  environment.systemPackages = with pkgs; [ flac ncmpcpp ];

  # Build MPD with libmp3lame support, so shoutcast output can do mp3.
  nixpkgs.config.packageOverrides = pkgs: {
    mpd = pkgs.mpd.overrideAttrs (oldAttrs: rec {
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.lame ];
    });
  };

  # Fancy graphs
  services.influxdb.enable = true;

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
