{ lib, ... }:

with lib;

{
  options.nixfiles.pleroma = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [Pleroma](https://pleroma.social/) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46283;
      description = ''
        Port (on 127.0.0.1) to expose Pleroma on.
      '';
    };

    postgresTag = mkOption {
      type = types.str;
      default = "16";
      description = ''
        Tag to use of the `postgres` container image.
      '';
    };

    domain = mkOption {
      type = types.str;
      example = "social.lainon.life";
      description = ''
        Domain which Pleroma will be exposed on.
      '';
    };

    faviconPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File to use for the favicon.
      '';
    };

    instanceName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Name of the instance, defaults to the `''${domain}` if not set.
      '';
    };

    adminEmail = mkOption {
      type = types.str;
      default = "mike@barrucadu.co.uk";
      description = ''
        Email address used to contact the server operator.
      '';
    };

    notifyEmail = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Email address used for notification, defaults to the `''${adminEmail}`
        if not set.
      '';
    };

    allowRegistration = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Allow new users to sign up.
      '';
    };

    secretsFile = mkOption {
      type = types.str;
      description = ''
        File containing secret configuration.

        See the Pleroma documentation for what this needs to contain.
      '';
    };
  };
}
