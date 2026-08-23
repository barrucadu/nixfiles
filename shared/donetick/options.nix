{ lib, ... }:

with lib;

{
  options.nixfiles.donetick = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [donetick](https://donetick.com/) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46399;
      description = ''
        Port (on 127.0.0.1) to expose Pleroma on.
      '';
    };

    tag = mkOption {
      type = types.str;
      default = "v0.1.76";
      description = ''
        Tag to use of the `donetick/donetick` container image.
      '';
    };

    domain = mkOption {
      type = types.str;
      example = "todo.nyarlathotep.lan";
      description = ''
        Domain which donetick will be exposed on.
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
      type = types.str;
      description = ''
        File containing secret configuration.

        Must include DT_JWT_SECRET.
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

          If enabled, the environment file must include DT_OAUTH2_CLIENT_SECRET.
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
          OAuth provider auth endpoint.
        '';
      };

      tokenUrl = mkOption {
        type = types.str;
        description = ''
          OAuth provider token endpoint.
        '';
      };

      userinfoUrl = mkOption {
        type = types.str;
        description = ''
          OAuth provider userinfo endpoint.
        '';
      };
    };
  };
}
