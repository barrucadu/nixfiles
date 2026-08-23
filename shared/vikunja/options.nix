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

    https = mkOption {
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

    allowUserCreation = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Allow users to sign up.
      '';
    };

    oidc = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Allow OIDC authentication.

          If enabled, the environment file must include VIKUNJA_AUTH_OPENID_PROVIDERS_DEFAULT_CLIENTSECRET.
        '';
      };

      name = mkOption {
        type = types.str;
        default = "OpenID Connect";
        description = ''
          Name of the OIDC provider, to show in the UI.
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
