{ lib, ... }:

with lib;
let
  portOptions = {
    host = mkOption {
      type = types.int;
      description = ''
        Host port (on 127.0.0.1) to expose the container port on.
      '';
    };

    inner = mkOption {
      type = types.int;
      description = ''
        The container port to expose to the hosti.
      '';
    };
  };

  volumeOptions = {
    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Name of the volume.  This is equivalent to:

        ```nix
        host = "''${volumeBaseDir}/''${volumeSubDir}/''${name}";
        ```

        This option c.logonflicts with `''${host}`.
      '';
    };

    host = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Directory on the host to bind-mount into the container.

        This option conflicts with `''${name}`.
      '';
    };

    inner = mkOption {
      type = types.str;
      description = ''
        Directory in the container to mount the volume to.
      '';
    };
  };

  containerOptions = {
    /* regular oci-containers */
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Start the container automatically on boot.
      '';
    };

    cmd = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Command-line arguments to pass to the container image's entrypoint.
      '';
    };

    dependsOn = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "concourse-db" ];
      description = ''
        Other containers that this one depends on, in `''${pod}-''${name}`
        format.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = ''
        Environment variables to set for this container.
      '';
    };

    environmentFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
        List of environment files for this container.
      '';
    };

    extraOptions = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Extra options to pass to `docker run` / `podman run`.
      '';
    };

    image = mkOption {
      type = types.str;
      description = ''
        Container image to run.
      '';
    };

    login = {
      username = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Username for the container registry.
        '';
      };
      passwordFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          File containing the password for the container registry.
        '';
      };
      registry = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Container registry to authenticate with.
        '';
      };
    };

    /* changed */
    ports = mkOption {
      type = types.listOf (types.submodule { options = portOptions; });
      default = [ ];
      description = ''
        List of ports to expose.
      '';
    };

    volumes = mkOption {
      type = types.listOf (types.submodule { options = volumeOptions; });
      default = [ ];
      description = ''
        List of volume definitions.
      '';
    };

    /* new options */
    pullOnStart = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Pull the container image when starting (useful for `:latest` images).
      '';
    };
  };
in
{
  options.nixfiles.oci-containers = {
    backend = mkOption {
      type = types.enum [ "docker" "podman" ];
      default = "docker";
      description = ''
        The container runtime.
      '';
    };

    pods = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          containers = mkOption {
            type = types.attrsOf (types.submodule { options = containerOptions; });
            default = { };
            description = ''
              Attrset of container definitions.
            '';
          };
          volumeSubDir = mkOption {
            type = types.str;
            default = name;
            description = ''
              Subdirectory of the `''${volumeBaseDir}` to store bind-mounts
              under.
            '';
          };
        };
      }));
      default = { };
      description = ''
        Attrset of pod definitions.
      '';
    };

    volumeBaseDir = mkOption {
      type = types.str;
      description = ''
        Directory to store volume bind-mounts under.

        If the `erase-your-darlings` module is enabled, this is overridden to be
        on the persistent volume.
      '';
    };
  };
}
