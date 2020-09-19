{ config, pkgs, lib, ... }:

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
  networking.firewall.allowedTCPPorts = [ 8888 ]; # for testing stuff

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
      proxy / http://localhost:${toString config.services.bookdb.httpPort}
    }

    http://bookmarks.nyarlathotep:80 {
      gzip
      proxy / http://localhost:${toString config.services.bookmarks.httpPort}
    }

    http://flood.nyarlathotep:80 {
      gzip
      proxy / http://localhost:3001
    }

    http://finder.nyarlathotep:80 {
      gzip
      proxy / http://localhost:${toString config.services.finder.httpPort}
    }

    http://*:80 {
      status 421 /
    }
  '';

  # bookdb
  services.bookdb.enable = true;
  services.bookdb.image = "localhost:5000/bookdb:latest";
  services.bookdb.baseURI = "http://bookdb.nyarlathotep";

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

  # bookmarks
  services.bookmarks.enable = true;
  services.bookmarks.image = "localhost:5000/bookmarks:latest";
  services.bookmarks.baseURI = "http://bookmarks.nyarlathotep";
  services.bookmarks.httpPort = 3003;
  services.bookmarks.youtubeApiKey = fileContents /etc/nixos/secrets/bookmarks-youtube-api-key.txt;

  systemd.timers.bookmarks-sync = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
    };
  };
  systemd.services.bookmarks-sync = {
    description = "Upload bookmarks data to dunwich";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ${pkgs.writeShellScript "bookmarks-sync.sh" (fileContents ./bookmarks-sync.sh)}";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };

  # docker registry
  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableGarbageCollect = true;
  virtualisation.docker.extraOptions = "--insecure-registry=localhost:5000";

  # finder
  services.finder.enable = true;
  services.finder.image = "localhost:5000/finder:latest";
  services.finder.httpPort = 3002;

  # rtorrent
  systemd.services.rtorrent = {
    enable   = true;
    wantedBy = [ "default.target" ];
    after    = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.zsh}/bin/zsh --login -c \"${pkgs.tmux}/bin/tmux new-session -d -s rtorrent '${pkgs.rtorrent}/bin/rtorrent -n -O directory=/srv/share/torrents/files -O scgi_local=/tmp/rtorrent-rpc.socket -O session=/srv/share/torrents/session -O dht=auto -O encryption=allow_incoming,try_outgoing,require,require_RC4 -O port_random=yes -O port_range=62001-63000 -O schedule=watch.directory,5,5,load.start=/srv/share/torrents/watch/\\*.torrent -O check_hash=yes -O encoding_list=UTF-8'\"";
      ExecStop  = "${pkgs.zsh}/bin/zsh --login -c '${pkgs.tmux}/bin/tmux send-keys -t rtorrent C-q'";
      User      = "barrucadu";
      KillMode  = "none";
      Type      = "forking";
      Restart   = "on-failure";
    };
  };

  systemd.services.flood = {
    enable   = true;
    wantedBy = [ "default.target" ];
    after    = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.zsh}/bin/zsh --login -c '${pkgs.nodejs-12_x}/bin/npm start'";
      User      = "barrucadu";
      KillMode  = "none";
      Restart   = "on-failure";
      WorkingDirectory = "/home/barrucadu/flood";
    };
  };

  environment.systemPackages = with pkgs;
    [
      mktorrent
      nodejs-12_x
      rtorrent
      tmux
    ];

  # hledger prices
  systemd.timers.hledger-scripts = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 21:00:00";
    };
  };
  systemd.services.hledger-scripts = {
    description = "Run hledger scripts";
    serviceConfig.WorkingDirectory = "/home/barrucadu/projects/hledger-scripts";
    serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c './sync.sh only-prices'";
    serviceConfig.User = "barrucadu";
    serviceConfig.Group = "users";
  };
}
