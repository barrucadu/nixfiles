{ lib, ... }:

with lib;

{
  options.nixfiles.torrents = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [Transmission](https://transmissionbt.com/) service.
      '';
    };

    downloadDir = mkOption {
      type = types.str;
      example = "/mnt/nas/torrents/files";
      description = ''
        Directory to download torrented files to.
      '';
    };

    stateDir = mkOption {
      type = types.str;
      example = "/var/lib/torrents";
      description = ''
        Directory to store service state in.
      '';
    };

    watchDir = mkOption {
      type = types.str;
      example = "/mnt/nas/torrents/watch";
      description = ''
        Directory to monitor for new .torrent files.
      '';
    };

    user = mkOption {
      type = types.str;
      description = ''
        The user to run Transmission as.
      '';
    };

    group = mkOption {
      type = types.str;
      description = ''
        The group to run Transmission as.
      '';
    };

    logLevel = mkOption {
      type = types.ints.between 0 6;
      default = 2;
      description = ''
        Verbosity of the log messages.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Allow connections from TCP and UDP ports `''${portRange.from}` to
        `''${portRange.to}`.
      '';
    };

    peerPort = mkOption {
      type = types.port;
      default = 50000;
      description = ''
        Port to accept peer connections on.
      '';
    };

    rpcPort = mkOption {
      type = types.port;
      default = 49528;
      description = ''
        Port to accept RPC connections on.  Bound on 127.0.0.1.
      '';
    };
  };
}
