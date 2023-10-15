{ lib, ... }:

with lib;

{
  options.nixfiles.bookmarks = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the bookmarks service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 48372;
      description = mdDoc ''
        Port (on 127.0.0.1) to expose the bookmarks service on.
      '';
    };

    esPort = mkOption {
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

    baseURI = mkOption {
      type = types.str;
      example = "https://bookmarks.barrucadu.co.uk";
      description = mdDoc ''
        URI which the service will be exposed on, used to generate URLs.
      '';
    };

    readOnly = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Whether to launch the service in "read-only" mode.  Enable this if
        exposing it to a public network.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        Environment file to be passed to the systemd services.  This needs to
        contain a `YOUTUBE_API_KEY` if not running in read-only mode.
      '';
    };
  };
}
