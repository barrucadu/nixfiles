{ lib, ... }:

with lib;

{
  options.nixfiles.pleroma = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the Pleroma service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46283;
      description = mdDoc ''
        Port (on 127.0.0.1) to expose Pleroma on.
      '';
    };

    pgTag = mkOption {
      type = types.str;
      default = "13";
      description = mdDoc ''
        Tag to use of the `postgres` container image.
      '';
    };

    domain = mkOption {
      type = types.str;
      example = "social.lainon.life";
      description = mdDoc ''
        Domain which Pleroma will be exposed on.
      '';
    };

    faviconPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = mdDoc ''
        Path to the favicon file.
      '';
    };

    instanceName = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        Name of the instance, defaults to the `''${domain}` if not set.
      '';
    };

    adminEmail = mkOption {
      type = types.str;
      default = "mike@barrucadu.co.uk";
      description = mdDoc ''
        Email address used to contact the server operator.
      '';
    };

    notifyEmail = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        Email address used for notification, defaults to the `''${adminEmail}`
        if not set.
      '';
    };

    allowRegistration = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Whether to allow new users to sign up.
      '';
    };

    secretsFile = mkOption {
      type = types.str;
      description = mdDoc ''
        Path to the secret configuration file.

        See the Pleroma documentation for what this needs to contain.
      '';
    };
  };
}
