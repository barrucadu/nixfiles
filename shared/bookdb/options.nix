{ lib, ... }:

with lib;

{
  options.nixfiles.bookdb = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the bookdb service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46667;
      description = mdDoc ''
        Port (on 127.0.0.1) to expose the bookdb service on.
      '';
    };

    esPort = mkOption {
      type = types.int;
      default = 47164;
      description = mdDoc ''
        Port (on 127.0.0.1) to expose the elasticsearch container on.
      '';
    };

    esTag = mkOption {
      type = types.str;
      default = "8.0.0";
      description = mdDoc ''
        Tag to use of the `elasticsearch` container image.
      '';
    };

    baseURI = mkOption {
      type = types.str;
      example = "https://bookdb.barrucadu.co.uk";
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

    dataDir = mkOption {
      type = types.str;
      default = "/srv/bookdb";
      description = mdDoc ''
        Directory to store uploaded files to.

        If the `erase-your-darlings` module is enabled, this is overridden to be
        on the persistent volume.
      '';
    };
  };
}
