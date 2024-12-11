{ lib, ... }:

with lib;

let
  backupOptions = {
    paths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of paths to back up.
      '';
    };

    prepareCommand = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        A script to run before beginning the backup.
      '';
    };

    cleanupCommand = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        A script to run after taking the backup.
      '';
    };

    startAt = mkOption {
      type = types.str;
      default = "Mon, 04:00";
      description = ''
        When to run the backup.
      '';
    };
  };

  sudoRuleOptions = {
    command = mkOption {
      type = types.str;
      description = ''
        The command for which the rule applies.
      '';
    };

    runAs = mkOption {
      type = types.str;
      default = "ALL:ALL";
      description = ''
        The user / group under which the command is allowed to run.

        A user can be specified using just the username: `"foo"`. It is also
        possible to specify a user/group combination using `"foo:bar"` or to
        only allow running as a specific group with `":bar"`.
      '';
    };
  };
in
{
  options.nixfiles.restic-backups = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the backup service.
      '';
    };

    backups = mkOption {
      type = types.attrsOf (types.submodule { options = backupOptions; });
      default = { };
      description = ''
        Attrset of backup job definitions.
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.str;
      description = ''
        Environment file to pass secrets into the service.  This is of the form:

        ```text
        # Repository password
        RESTIC_PASSWORD="..."

        # B2 credentials
        B2_ACCOUNT_ID="..."
        B2_ACCOUNT_KEY="..."

        # AWS SNS credentials
        AWS_ACCESS_KEY="..."
        AWS_SECRET_ACCESS_KEY="..."
        AWS_DEFAULT_REGION="..."
        ```

        If any of the backup jobs need secrets, those should be specified in
        this file as well.
      '';
    };

    sudoRules = mkOption {
      type = types.listOf (types.submodule { options = sudoRuleOptions; });
      default = [ ];
      description = ''
        List of additional sudo rules to grant the backup user.
      '';
    };

    checkRepositoryAt = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        If not null, when to run `restic check` to validate the repository
        metadata.
      '';
    };
  };
}
