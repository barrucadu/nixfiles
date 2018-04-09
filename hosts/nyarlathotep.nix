{ pkgs, lib, ... }:

# Bring names from 'lib' into scope.
with lib;

let
  shares = [ "anime" "manga" "music" "movies" "tv" "images" "torrents" ];
in

{
  networking.hostName = "nyarlathotep";
  networking.hostId = "4a592971"; # ZFS needs one of these
  boot.supportedFilesystems = [ "zfs" ];

  imports = [
    ./common.nix
    ./hardware-configuration.nix
  ];

  # Bootloader
  boot.loader.systemd-boot.enable = true;

  # Enable wifi
  networking.wireless.enable = true;

  # Static ethernet
  networking.interfaces.enp3s0.ipv4.addresses =
    [ { address = "10.1.1.1"; prefixLength = 24; } ];

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "lo" "enp3s0" ];
  networking.firewall.extraCommands = ''
    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -i wlp2s0 -j DROP
  '';

  # NFS exports
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /srv/share/ 10.1.1.0/24(rw,fsid=root,no_subtree_check)
    ${concatMapStringsSep "\n" (n: "/srv/share/${n} 10.1.1.0/24(rw,no_subtree_check,nohide)") shares}
  '';

  # Samba
  services.samba.enable = true;
  services.samba.shares = listToAttrs
    (map (n: nameValuePair n { path = "/srv/share/${n}"; writable = "yes"; }) shares);
  services.samba.extraConfig = ''
    hosts allow = 10.1.1. 127.
    log file = /var/log/samba/%m.log
  '';
  services.samba.syncPasswordsByPam = true;

  # nginx
  services.nginx.enable = true;
  services.nginx.config = ''
    worker_processes 1;
    events {
      worker_connections 1024;
    }
    http {
      include ${pkgs.nginx}/conf/mime.types;
      default_type application/octet-stream;
      sendfile on;
      keepalive_timeout 65;
      gzip on;
      error_log /var/spool/nginx/logs/errors.log;
      server {
        listen 10.1.1.1:80;
        location / {
          proxy_read_timeout 300;
          proxy_connect_timeout 300;
          proxy_pass http://127.0.0.1:3000;
        }
      }
    }
  '';

  # Extra packages
  environment.systemPackages = with pkgs; [
    rtorrent
  ];
}
