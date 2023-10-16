{ lib, ... }:

with lib;

{
  options.nixfiles.backups = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the backup service.
      '';
    };

    scripts = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = mdDoc ''
        Attrset of bash scripts to run.  The name is the name of the script's
        working directory.
      '';
    };

    pythonScripts = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = mdDoc ''
        Attrset of python scripts to run.  The name is the name of the script's
        working directory.
      '';
    };

    sudoRules = mkOption {
      type = types.listOf (types.submodule {
        options = {
          command = mkOption {
            type = types.str;
            description = mdDoc ''
              The command for which the rule applies.
            '';
          };
          runAs = mkOption {
            type = types.str;
            default = "ALL:ALL";
            description = mdDoc ''
              The user / group under which the command is allowed to run.

              A user can be specified using just the username: `"foo"`. It is
              also possible to specify a user/group combination using
              `"foo:bar"` or to only allow running as a specific group with
              `":bar"`.
            '';
          };
        };
      });
      default = { };
      description = mdDoc ''
        List of additional sudo rules to grant the backup user.
      '';
    };

    environmentFile = mkOption {
      type = types.str;
      description = mdDoc ''
        Environment file to pass secrets into the service.  This is of the form:

        ```text
        # Duplicity encryption password
        PASSPHRASE="..."

        # AWS S3 & SNS credentials
        AWS_ACCESS_KEY="..."
        AWS_SECRET_ACCESS_KEY="..."
        AWS_DEFAULT_REGION="..."

        # SNS topic to send alerts to
        TOPIC_ARN="..."
        ```

        If any of the `scripts` or `pythonScripts` need secrets, those should be
        specified in this file as well.
      '';
    };

    onCalendarFull = mkOption {
      type = types.str;
      default = "monthly";
      description = mdDoc ''
        The cadence of the full backup job.
      '';
    };

    onCalendarIncr = mkOption {
      type = types.str;
      default = "Mon, 04:00";
      description = mdDoc ''
        The cadence of the incremental backup job.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "barrucadu";
      description = mdDoc ''
        The user to generate the backup as.
      '';
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = mdDoc ''
        The group to generate the backup as.
      '';
    };
  };
}
