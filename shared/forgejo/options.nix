{ lib, ... }:

with lib;

{
  options.nixfiles.forgejo = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [Forgejo](https://forgejo.org/.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46484;
      description = ''
        Port (on 127.0.0.1) to expose Forgejo on.
      '';
    };

    postgresTag = mkOption {
      type = types.str;
      default = "18";
      description = ''
        Tag to use of the `postgres` container image.
      '';
    };

    domain = mkOption {
      type = types.str;
      example = "git.barrucadu.dev";
      description = ''
        Domain which Forgejo will be exposed on.
      '';
    };

    runnerTokenPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        File in the format 'TOKEN=...' with the runner token.  If not specified,
        the runner is not enabled.
      '';
    };

    adminUserName = mkOption {
      type = types.str;
      default = "root";
      description = ''
        Name of the admin user (note: cannot be 'admin' as forgejo prevents
        creation of a user called 'admin').
      '';
    };

    adminUserPasswordPath = mkOption {
      type = types.path;
      description = ''
        Path to a file containing the admin user password.
      '';
    };
  };
}
