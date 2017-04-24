{ config, pkgs, lib, ... }:

let
  radio = import ./hosts/lainonlife/radio.nix { inherit pkgs; };
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
    locations."/radio/".proxyPass = "http://localhost:8000/";
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

  # Radio (one MPD entry per channel)
  users.extraUsers."${radio.username}" = radio.userSettings;
  services.icecast = radio.icecastSettings;
  systemd.services."mpd-random" = radio.mpdServiceFor { channel = "random"; port = 6600; description = "Anything and everything!"; };
  environment.systemPackages = [ pkgs.ncmpcpp ];

  # Build MPD with libmp3lame support, so shoutcast output can do mp3.
  nixpkgs.config.packageOverrides = pkgs: {
    mpd = pkgs.mpd.overrideAttrs (oldAttrs: rec {
      buildInputs = oldAttrs.buildInputs ++ [ pkgs.lame ];
    });
  };

  # Extra users
  users.extraUsers.appleman1234 = {
    uid = 1001;
    description = "Appleman1234 <admin@lainchan.org>";
    isNormalUser = true;
    group = "users";
  };
}
