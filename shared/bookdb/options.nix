{ lib, ... }:

with lib;

{
  options.nixfiles.bookdb = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [bookdb](https://github.com/barrucadu/bookdb) service.
      '';
    };

    port = mkOption {
      type = types.int;
      default = 46667;
      description = ''
        Port (on 127.0.0.1) to expose bookdb on.
      '';
    };

    elasticsearchPort = mkOption {
      type = types.int;
      default = 47164;
      description = ''
        Port (on 127.0.0.1) to expose the elasticsearch container on.
      '';
    };

    elasticsearchTag = mkOption {
      type = types.str;
      default = "9.0.1";
      description = ''
        Tag to use of the `elasticsearch` container image.
      '';
    };

    readOnly = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Launch the service in "read-only" mode.  Enable this if exposing it to a
        public network.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = "/srv/bookdb";
      description = ''
        Directory to store uploaded files to.

        If the `erase-your-darlings` module is enabled, this is overridden to be
        on the persistent volume.
      '';
    };

    logLevel = mkOption {
      type = types.str;
      default = "info";
      description = ''
        Verbosity of the log messages.
      '';
    };

    logFormat = mkOption {
      type = types.str;
      default = "json,no-time";
      description = ''
        Format of the log messages.
      '';
    };

    remoteSync = {
      receive = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable receiving push-based remote sync from other hosts.
          '';
        };
        authorizedKeys = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            SSH public keys to allow pushes from.
          '';
        };
      };

      send = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable periodically pushing local state to other hosts.
          '';
        };
        sshKeyFile = mkOption {
          type = types.str;
          description = ''
            Path to SSH private key.
          '';
        };
        targets = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = ''
            Hosts to push to.
          '';
        };
      };
    };
  };
}
