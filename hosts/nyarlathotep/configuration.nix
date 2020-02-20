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

  # caddy
  services.caddy.enable = true;
  services.caddy.config = ''
    http://nyarlathotep:80 {
      gzip
      root /srv/http
    }

    http://bookdb.nyarlathotep:80 {
      gzip
      proxy / http://localhost:3000
    }

    http://flood.nyarlathotep:80 {
      gzip
      proxy / http://localhost:3001
    }

    http://grafana.nyarlathotep:80 {
      gzip
      proxy / http://localhost:3002
    }

    http://finder.nyarlathotep:80 {
      gzip
      proxy / http://localhost:3003
    }

    http://*:80 {
      status 421 /
    }
  '';

  # bookdb
  services.bookdb.enable = true;
  services.bookdb.image = "localhost:5000/bookdb:latest";
  services.bookdb.webRoot = "http://bookdb.nyarlathotep";

  systemd.timers.bookdb-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
    };
  };
  systemd.services.bookdb-sync = {
    description = "Upload bookdb data to dunwich";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ${pkgs.writeShellScript "bookdb-sync.sh" (fileContents ./bookdb-sync.sh)}";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };

  # docker registry
  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableGarbageCollect = true;
  virtualisation.docker.extraOptions = "--insecure-registry=localhost:5000";

  # rtorrent
  services.rtorrent.enable = true;

  # finder
  services.elasticsearch.enable = true;

  systemd.services.finder = {
    enable   = true;
    wantedBy = [ "multi-user.target" ];
    after    = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.zsh}/bin/zsh --login -c './run-finder --port=3003'";
      Restart   = "on-failure";
      WorkingDirectory = "/srv/finder";
    };
  };
}
