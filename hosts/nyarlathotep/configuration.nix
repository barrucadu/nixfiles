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
    ../services/bookdb.nix
    ../services/nginx.nix
    ../services/rtorrent.nix
  ];

  services.monitoring-scripts.OnCalendar = "0/12:00:00";

  # Bootloader
  boot.loader.systemd-boot.enable = true;

  # Monthly ZFS scrub
  services.zfs.autoScrub.enable = true;
  services.zfs.autoScrub.interval = "monthly";

  # Firewall
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "lo" "enp4s0" ];

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
  services.nginx.virtualHosts = {
    nyarlathotep = {
      default = true;
      globalRedirect = "nyarlathotep.barrucadu.co.uk";
    };
    "nyarlathotep.barrucadu.co.uk" = {
      enableACME = true;
      forceSSL = true;
      root = "/srv/http";
      locations."/bookdb".extraConfig  = "rewrite ^/bookdb(.*)$  https://bookdb.barrucadu.co.uk$1  permanent;";
      locations."/flood".extraConfig   = "rewrite ^/flood(.*)$   https://flood.barrucadu.co.uk$1   permanent;";
      locations."/grafana".extraConfig = "rewrite ^/grafana(.*)$ https://grafana.barrucadu.co.uk$1 permanent;";
    };
    "bookdb.nyarlathotep.barrucadu.co.uk" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:3000/";
        extraConfig = ''
          auth_basic "bookdb";
          auth_basic_user_file ${pkgs.writeText "bookdb.htpasswd" (import /etc/nixos/secrets/bookdb-htpasswd.nix)};
        '';
      };
    };
    "flood.nyarlathotep.barrucadu.co.uk" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:3001/";
    };
    "grafana.nyarlathotep.barrucadu.co.uk" = {
      enableACME = true;
      forceSSL = true;
      locations."/".proxyPass = "http://localhost:3002/";
    };
  };

  # hledger dashboard
  services.grafana = {
    enable = true;
    port = 3002;
    domain = "grafana.nyarlathotep.barrucadu.co.uk";
    rootUrl = "https://grafana.nyarlathotep.barrucadu.co.uk/";
  };

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
    description = "Upload bookdb data to dunwich";
    serviceConfig.WorkingDirectory = "/srv/bookdb";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ./upload.sh";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };

  # Extra packages
  environment.systemPackages = with pkgs; [
    influxdb
  ];
}
