{ lib, ... }:

with lib;

{
  options.nixfiles.vikunja = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [vikunja](https://vikunja.io/) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46346;
      description = ''
        Port (on 127.0.0.1) to expose vikunja on.
      '';
    };

    domain = mkOption {
      type = types.str;
      example = "todo.nyarlathotep.lan";
      description = ''
        Domain which vikunja will be exposed on.
      '';
    };

    urlsAreHTTPS = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to use https:// in generated URLs.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/vikunja";
      description = ''
        Directory to store the database and other files to.

        If the `erase-your-darlings` module is enabled, this is overridden to be
        on the persistent volume.
      '';
    };

    environmentFile = mkOption {
      type = types.str;
      description = ''
        File containing secret configuration.
      '';
    };
  };
}
