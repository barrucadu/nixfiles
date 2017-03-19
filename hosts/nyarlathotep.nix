{ pkgs, ... }:

{
  networking.hostName = "nyarlathotep";
  networking.hostId = "4a592971"; # ZFS needs one of these
  boot.supportedFilesystems = [ "zfs" ];

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # Include the standard configuration.
      ./common.nix

      # Include other configuration.
      ./misc/kernel.nix
    ];

  # UEFI
  boot.loader.systemd-boot.enable = true;

  # Enable wifi
  networking.wireless.enable = true;

  # Static ethernet
  networking.interfaces.enp3s0.ipAddress = "10.1.1.1";
  networking.interfaces.enp3s0.prefixLength = 24;

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
    /srv/share/         10.1.1.0/24(rw,fsid=root,no_subtree_check)
    /srv/share/anime    10.1.1.0/24(rw,no_subtree_check,nohide)
    /srv/share/music    10.1.1.0/24(rw,no_subtree_check,nohide)
    /srv/share/movies   10.1.1.0/24(rw,no_subtree_check,nohide)
    /srv/share/tv       10.1.1.0/24(rw,no_subtree_check,nohide)
    /srv/share/images   10.1.1.0/24(rw,no_subtree_check,nohide)
    /srv/share/torrents 10.1.1.0/24(rw,no_subtree_check,nohide)
  '';

  # Samba
  services.samba.enable = true;
  services.samba.shares = {
    anime    = { path = "/srv/share/anime";    writable = "yes"; };
    movies   = { path = "/srv/share/movies";   writable = "yes"; };
    music    = { path = "/srv/share/music";    writable = "yes"; };
    tv       = { path = "/srv/share/tv";       writable = "yes"; };
    images   = { path = "/srv/share/images";   writable = "yes"; };
    torrents = { path = "/srv/share/torrents"; writable = "yes"; };
  };
  services.samba.extraConfig = ''
    hosts allow = 10.1.1. 127.
    log file = /var/log/samba/%m.log
  '';
  services.samba.syncPasswordsByPam = true;

  # Plex Media Server
  #
  # extra set-up: install the Absolute Series Scanner and Hama plugins in /var.
  services.plex.enable = true;
  services.plex.managePlugins = false;

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
