{ lib, ... }:

with lib;

{
  options.nixfiles.rtorrent = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the [rTorrent](https://github.com/rakshasa/rtorrent) service.
      '';
    };

    downloadDir = mkOption {
      type = types.str;
      example = "/mnt/nas/torrents/files/";
      description = mdDoc ''
        Directory to download torrented files to.
      '';
    };

    watchDir = mkOption {
      type = types.str;
      example = "/mnt/nas/torrents/watch/";
      description = mdDoc ''
        Directory to monitor for new .torrent files.
      '';
    };

    user = mkOption {
      type = types.str;
      description = mdDoc ''
        The user to run rTorrent as.
      '';
    };

    logLevels = mkOption {
      type = types.listOf types.str;
      default = [ "info" ];
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

    portRange = {
      from = mkOption {
        type = types.int;
        default = 50000;
        description = mdDoc ''
          Lower bound (inclusive) of the port range to accept connections on.
        '';
      };
      to = mkOption {
        type = types.int;
        default = 50000;
        description = mdDoc ''
          Upper bound (inclusive) of the port range to accept connections on.
        '';
      };
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
        type = types.int;
        default = 45904;
        description = mdDoc ''
          Port (on 127.0.0.1) to expose Flood on.
        '';
      };
    };
  };
}
