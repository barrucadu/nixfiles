{ lib, ... }:

with lib;

{
  options.nixfiles.bookdb = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the [bookdb](https://github.com/barrucadu/bookdb) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46667;
      description = mdDoc ''
        Port (on 127.0.0.1) to expose bookdb on.
      '';
    };

    elasticsearchPort = mkOption {
      type = types.int;
      default = 47164;
      description = mdDoc ''
        Port (on 127.0.0.1) to expose the elasticsearch container on.
      '';
    };

    elasticsearchTag = mkOption {
      type = types.str;
      default = "8.0.0";
      description = mdDoc ''
        Tag to use of the `elasticsearch` container image.
      '';
    };

    readOnly = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Launch the service in "read-only" mode.  Enable this if exposing it to a
        public network.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "/srv/bookdb";
      description = mdDoc ''
        Directory to store uploaded files to.

        If the `erase-your-darlings` module is enabled, this is overridden to be
        on the persistent volume.
      '';
    };

    logLevel = mkOption {
      type = types.str;
      default = "info";
      description = mdDoc ''
        Verbosity of the log messages.
      '';
    };

    logFormat = mkOption {
      type = types.str;
      default = "json,no-time";
      description = mdDoc ''
        Format of the log messages.
      '';
    };
  };
}
