{ lib, ... }:

with lib;
let
  portOptions = {
    host = mkOption {
      type = types.int;
      description = mdDoc ''
        Host port (on 127.0.0.1) to expose the inner port on.
      '';
    };

    inner = mkOption {
      type = types.int;
      description = mdDoc ''
        Container port.
      '';
    };
  };

  volumeOptions = {
    name = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        Name of the volume.  This creates a bind-mount to
        `''${volumeBaseDir}/''${volumeSubDir}/''${name}`.

        Exactly one of this or `''${host}` must be specified.
      '';
    };

    host = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        Directory on the host to bind-mount into the container.

        Exactly one of this or `''${name}` must be specified.
      '';
    };

    inner = mkOption {
      type = types.str;
      description = mdDoc ''
        Directory in the container to mount the volume to.
      '';
    };
  };

  containerOptions = {
    /* regular oci-containers */
    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc ''
        Whether to start the container automatically on boot.
      '';
    };

    cmd = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = mdDoc ''
        Command-line arguments to pass to the container image's entrypoint.
      '';
    };

    dependsOn = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = mdDoc ''
        Other containers that this one depends on.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = mdDoc ''
        Environment variables to set for this container.
      '';
    };

    environmentFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = mdDoc ''
        List of environment files for this container.
      '';
    };

    extraOptions = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = mdDoc ''
        Extra options to pass to `docker run` / `podman run`.
      '';
    };

    image = mkOption {
      type = types.str;
      description = mdDoc ''
        Container image to run.
      '';
    };

    login = {
      username = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc ''
          Username for the container registry.
        '';
      };
      passwordFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc ''
          File containing the password for the container registry.
        '';
      };
      registry = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = mdDoc ''
          Container registry to authenticate with.
        '';
      };
    };

    /* changed */
    ports = mkOption {
      type = types.listOf (types.submodule { options = portOptions; });
      default = [ ];
      description = mdDoc ''
        List of ports to expose.
      '';
    };

    volumes = mkOption {
      type = types.listOf (types.submodule { options = volumeOptions; });
      default = [ ];
      description = mdDoc ''
        List of volume definitions.
      '';
    };

    /* new options */
    pullOnStart = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc ''
        Whether to pull the container image when starting (useful for `:latest`
        images).
      '';
    };
  };
in
{
  options.nixfiles.oci-containers = {
    backend = mkOption {
      type = types.enum [ "docker" "podman" ];
      default = "docker";
      description = mdDoc ''
        The container runtime.
      '';
    };

    containers = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options =
          containerOptions //
          {
            pod = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = mdDoc ''
                Pod to attach the container to.  This is only valid if using
                podman as the backend.
              '';
            };
            network = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = mdDoc ''
                Network to attach the container to.  This is only valid if using
                docker as the backend.
              '';
            };
            volumeSubDir = mkOption {
              type = types.str;
              default = name;
              description = mdDoc ''
                Subdirectory of the `''${volumeBaseDir}` to store bind-mounts
                under.
              '';
            };
          };
      }));
      default = { };
      description = mdDoc ''
        Attrset of container definitions.
      '';
    };

    pods = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          containers = mkOption {
            type = types.attrsOf (types.submodule { options = containerOptions; });
            default = { };
            description = mdDoc ''
              Attrset of container definitions.
            '';
          };
          volumeSubDir = mkOption {
            type = types.str;
            default = name;
            description = mdDoc ''
              Subdirectory of the `''${volumeBaseDir}` to store bind-mounts
              under.
            '';
          };
        };
      }));
      default = { };
      description = mdDoc ''
        Attrset of pod definitions.
      '';
    };

    volumeBaseDir = mkOption {
      type = types.str;
      description = mdDoc ''
        Directory to store volume bind-mounts under.

        If the `erase-your-darlings` module is enabled, this is overridden to be
        on the persistent volume.
      '';
    };
  };
}
