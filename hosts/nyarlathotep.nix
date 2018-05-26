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

  # DNS & DHCP for LAN
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

    address=/nyarlathotep/10.1.1.1
    address=/nyarlathotep.dot/10.1.1.1

    dhcp-option=3
    dhcp-option=6,10.1.1.1
    dhcp-range=10.1.1.100,10.1.1.200
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

  # hledger dashboard
  services.influxdb.enable = true;
  services.grafana.enable  = true;
  services.grafana.addr = "0.0.0.0";
  services.grafana.port = 3333;

  systemd.timers.hledger-scripts = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 21:00:00";
    };
  };
  systemd.services.hledger-scripts = {
    description = "Run hledger scripts";
    serviceConfig.WorkingDirectory = "/home/barrucadu/projects/hledger-scripts";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ./sync.sh";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };

  # bookdb database sync
  systemd.timers.bookdb-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
    };
  };
  systemd.services.bookdb-sync = {
    description = "Upload bookdb data to innsmouth";
    serviceConfig.WorkingDirectory = "/srv/http/bookdb";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ./upload.sh";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };

  # Extra packages
  environment.systemPackages = with pkgs; [
    influxdb
    rtorrent
  ];
}
