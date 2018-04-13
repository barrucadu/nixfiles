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
  networking.interfaces.enp3s0.ipv6.addresses =
    [ { address = "fdb1:652e:e9ce:19aa::1"; prefixLength = 64; } ];

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "lo" "enp3s0" ];
  networking.firewall.extraCommands = ''
    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -i wlp2s0 -j DROP
  '';

  # DNS & DHCP for IPv6 LAN
  #
  # note: it would be nice to be able to resolve LAN hostnames (eg:
  # azathoth.dot works automagically), but I haven't been able to make
  # that happen, despite everything I read saying it should just work
  # out of the box.
  services.dnsmasq.enable = true;
  services.dnsmasq.extraConfig = ''
    domain-needed
    bogus-priv

    local=/dot/
    domain=dot
    dhcp-fqdn
    dhcp-authoritative
    no-hosts

    except-interface=wlp2s0
    bind-interfaces

    address=/nyarlathotep/fdb1:652e:e9ce:19aa::1
    address=/nyarlathotep.dot/fdb1:652e:e9ce:19aa::1

    enable-ra
    dhcp-option=option6:dns-server,[fdb1:652e:e9ce:19aa::1]

    dhcp-range=::100,::1ff,constructor:enp3s0
  '';

  # NFS exports
  services.nfs.server.enable = true;
  services.nfs.server.exports = ''
    /srv/share/ *(rw,fsid=root,no_subtree_check)
    ${concatMapStringsSep "\n" (n: "/srv/share/${n} *(rw,no_subtree_check,nohide)") shares}
  '';

  # Samba
  services.samba.enable = true;
  services.samba.shares = listToAttrs
    (map (n: nameValuePair n { path = "/srv/share/${n}"; writable = "yes"; }) shares);
  services.samba.extraConfig = ''
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
        listen [::]:80 ipv6only=off;
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
