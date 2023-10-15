{ lib, ... }:

with lib;

{
  options.nixfiles.umami = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the umami service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46489;
      description = mdDoc ''
        Port (on 127.0.0.1) to expose umami on.
      '';
    };

    postgresTag = mkOption {
      type = types.str;
      default = "13";
      description = mdDoc ''
        Tag to use of the `postgres` container image.
      '';
    };

    umamiTag = mkOption {
      type = types.str;
      default = "postgresql-latest";
      description = mdDoc ''
        Tag to use of the `ghcr.io/mikecao/umami` container image.
      '';
    };

    environmentFile = mkOption {
      type = types.str;
      description = mdDoc ''
        Environment file to be pased to the container.  This needs to contain a
        `HASH_SALT`.
      '';
    };
  };
}
