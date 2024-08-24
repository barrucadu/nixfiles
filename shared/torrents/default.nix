# [Transmission][] is a bittorrent client.  This module configures it along with
# a web UI ([Flood][]).
#
# This module does not include a backup script.  Torrented files must be backed
# up independently.
#
# **Erase your darlings:** transparently stores session data on the persistent
# volume.
#
# [Transmission]: https://transmissionbt.com/
# [Flood]: https://flood.js.org/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.torrents;
in
{
  imports = [
    ./erase-your-darlings.nix
    ./options.nix
  ];

  config = mkIf cfg.enable {
    services.transmission = {
      enable = true;
      user = cfg.user;
      group = cfg.group;
      home = "${cfg.stateDir}/transmission";
      openPeerPorts = cfg.openFirewall;
      settings = {
        # paths
        download-dir = cfg.downloadDir;
        watch-dir = cfg.watchDir;
        watch-dir-enabled = true;
        incomplete-dir-enabled = false;

        # optimise for private trackers (disable DHT and PEX, force encryption)
        encryption = 2;
        dht-enabled = false;
        pex-enabled = false;

        # peers
        peer-port = cfg.peerPort;
        peer-port-random-on-start = false;

        # rpc
        rpc-bind-address = "127.0.0.1";
        rpc-port = cfg.rpcPort;

        # misc
        message-level = cfg.logLevel;
        rename-partial-files = false;
        trash-can-enabled = false;
        trash-original-torrent-files = false;
      };
    };

    systemd.services.flood = mkIf cfg.flood.enable {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      after = [ "transmission.service" ];
      requires = [ "transmission.service" ];
      serviceConfig = {
        # flood needs `--truser` and `--trpass` passing even though the RPC
        # socket is unauthenticated
        ExecStart = concatStringsSep " " [
          "${pkgs.flood}/bin/flood "
          "--noauth "
          "--port=${toString cfg.flood.port} "
          "--rundir=${cfg.stateDir}/flood "
          "--trurl=http://127.0.0.1:${toString cfg.rpcPort}/transmission/rpc"
          "--truser=transmission"
          "--trpass=transmission"
        ];
        User = cfg.user;
        Restart = "on-failure";
      };
    };
  };
}
