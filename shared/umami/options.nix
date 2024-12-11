{ lib, ... }:

with lib;

{
  options.nixfiles.umami = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [umami](https://umami.is/) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46489;
      description = ''
        Port (on 127.0.0.1) to expose umami on.
      '';
    };

    postgresTag = mkOption {
      type = types.str;
      default = "16";
      description = ''
        Tag to use of the `postgres` container image.
      '';
    };

    umamiTag = mkOption {
      type = types.str;
      default = "postgresql-v2.9.0";
      description = ''
        Tag to use of the `ghcr.io/umami-software/umami` container image.
      '';
    };

    environmentFile = mkOption {
      type = types.str;
      description = ''
        Environment file to pass secrets into the service.  This is of the form:

        ```text
        HASH_SALT="..."
        ```
      '';
    };
  };
}
