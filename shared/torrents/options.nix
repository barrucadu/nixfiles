{ lib, ... }:

with lib;

{
  options.nixfiles.torrents = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the [Transmission](https://transmissionbt.com/) service.
      '';
    };

    downloadDir = mkOption {
      type = types.str;
      example = "/mnt/nas/torrents/files";
      description = mdDoc ''
        Directory to download torrented files to.
      '';
    };

    stateDir = mkOption {
      type = types.str;
      example = "/var/lib/torrents";
      description = mdDoc ''
        Directory to store service state in.
      '';
    };

    watchDir = mkOption {
      type = types.str;
      example = "/mnt/nas/torrents/watch";
      description = mdDoc ''
        Directory to monitor for new .torrent files.
      '';
    };

    user = mkOption {
      type = types.str;
      description = mdDoc ''
        The user to run Transmission as.
      '';
    };

    group = mkOption {
      type = types.str;
      description = mdDoc ''
        The group to run Transmission as.
      '';
    };

    logLevel = mkOption {
      type = types.ints.between 0 6;
      default = 2;
      description = mdDoc ''
        Verbosity of the log messages.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc ''
        Allow connections from TCP and UDP ports `''${portRange.from}` to
        `''${portRange.to}`.
      '';
    };

    peerPort = mkOption {
      type = types.port;
      default = 50000;
      description = mdDoc ''
        Port to accept peer connections on.
      '';
    };

    rpcPort = mkOption {
      type = types.port;
      default = 49528;
      description = mdDoc ''
        Port to accept RPC connections on.  Bound on 127.0.0.1.
      '';
    };

    flood = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = mdDoc ''
          Enable the [Flood](https://flood.js.org/) web UI.
        '';
      };
      port = mkOption {
        type = types.port;
        default = 45904;
        description = mdDoc ''
          Port (on 127.0.0.1) to expose Flood on.
        '';
      };
    };
  };
}
