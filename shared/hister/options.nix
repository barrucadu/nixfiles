{ lib, ... }:

with lib;

{
  options.nixfiles.hister = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [hister](https://hister.org/) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46556;
      description = ''
        Port (on 127.0.0.1) to expose hister on.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/hister";
      description = ''
        Directory to store the search database in.

        If the `erase-your-darlings` module is enabled, this is overridden to be
        on the persistent volume.
      '';
    };

    domain = mkOption {
      type = types.str;
      example = "search.nyarlathotep.lan";
      description = ''
        Domain which hister will be exposed on.
      '';
    };

    https = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to use https:// in generated URLs.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        File containing secret configuration.
      '';
    };

    oidc = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Allow OIDC authentication.

          If enabled, the environment file must include HISTER__SERVER__OAUTH__OIDC__CLIENT_SECRET.
        '';
      };

      clientId = mkOption {
        type = types.str;
        description = ''
          OAuth client ID.
        '';
      };

      authUrl = mkOption {
        type = types.str;
        description = ''
          OAuth provider domain (for discovery).
        '';
      };
    };
  };
}
