{ lib, ... }:

with lib;

{
  options.nixfiles.bookmarks = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the [bookmarks](https://github.com/barrucadu/bookmarks) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 48372;
      description = mdDoc ''
        Port (on 127.0.0.1) to expose bookmarks on.
      '';
    };

    elasticsearchPort = mkOption {
      type = types.int;
      default = 43389;
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
