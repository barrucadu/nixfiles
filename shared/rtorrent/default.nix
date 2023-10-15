{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.rtorrent;

  stateDir = "/var/lib/rtorrent";
  logDir = "/var/log/rtorrent";
  rpcSocketPath = "/run/rtorrent/rpc.sock";

  rtorrentrc = pkgs.writeText "rtorrent.rc" ''
    # Paths
    directory.default.set = ${cfg.downloadDir}
    session.path.set      = ${stateDir}/session/

    # Logging
    method.insert = cfg.logfile, private|const|string, (cat,"${logDir}/",(system.time),".log")
    log.open_file = "log", (cfg.logfile)
    ${concatMapStringsSep "\n" (lvl: "log.add_output = \"${lvl}\", \"log\"") cfg.logLevels}

    # Listening port for incoming peer traffic
    network.port_range.set  = ${toString cfg.portRange.from}-${toString cfg.portRange.to}
    network.port_random.set = no

    # Optimise for private trackers (disable DHT & UDP trackers)
    dht.mode.set         = disable
    protocol.pex.set     = no
    trackers.use_udp.set = no

    # Force encryption
    protocol.encryption.set = allow_incoming,try_outgoing,require,require_RC4

    # Write filenames in UTF-8
    encoding.add = UTF-8

    # File options
    pieces.hash.on_completion.set = yes
    pieces.sync.always_safe.set = yes

    # Monitor for new .torrent files
    schedule2 = watch_directory,5,5,load.start=${cfg.watchDir}*.torrent

    # XMLRPC
    network.scgi.open_local = ${rpcSocketPath}
  '';

in
{
  imports = [
    ./erase-your-darlings.nix
    ./options.nix
  ];

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPortRanges = mkIf cfg.openFirewall [ cfg.portRange ];

    systemd.services.rtorrent = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.rtorrent}/bin/rtorrent -n -o system.daemon.set=true -o import=${rtorrentrc}";
        User = cfg.user;
        Restart = "on-failure";
        LogsDirectory = "rtorrent";
        RuntimeDirectory = "rtorrent";
        StateDirectory = "rtorrent/session";
        # with a lot of torrents, rtorrent can take a while to shut down
        TimeoutStopSec = 300;
      };
    };

    systemd.services.flood = mkIf cfg.flood.enable {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "rtorrent.service" ];
      requires = [ "rtorrent.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.flood}/bin/flood --noauth --port=${toString cfg.flood.port} --rundir=${stateDir}/flood --rtsocket=${rpcSocketPath}";
        User = cfg.user;
        Restart = "on-failure";
        StateDirectory = "rtorrent/flood";
      };
    };
  };
}
