{ lib, ... }:

with lib;
let
  portOptions = {
    host = mkOption { type = types.int; };
    inner = mkOption { type = types.int; };
  };

  volumeOptions = {
    name = mkOption { type = types.nullOr types.str; default = null; };
    host = mkOption { type = types.nullOr types.str; default = null; };
    inner = mkOption { type = types.str; };
  };

  containerOptions = {
    /* regular oci-containers */
    autoStart = mkOption { type = types.bool; default = true; };
    cmd = mkOption { type = types.listOf types.str; default = [ ]; };
    dependsOn = mkOption { type = types.listOf types.str; default = [ ]; };
    environment = mkOption { type = types.attrsOf types.str; default = { }; };
    environmentFiles = mkOption { type = types.listOf types.path; default = [ ]; };
    extraOptions = mkOption { type = types.listOf types.str; default = [ ]; };
    image = mkOption { type = types.str; };
    login.username = mkOption { type = types.nullOr types.str; default = null; };
    login.passwordFile = mkOption { type = types.nullOr types.str; default = null; };
    login.registry = mkOption { type = types.nullOr types.str; default = null; };
    /* changed */
    ports = mkOption { type = types.listOf (types.submodule { options = portOptions; }); default = [ ]; };
    volumes = mkOption { type = types.listOf (types.submodule { options = volumeOptions; }); default = [ ]; };
    /* new options */
    pullOnStart = mkOption { type = types.bool; default = true; };
  };
in
{
  options.nixfiles.oci-containers = {
    backend = mkOption { type = types.enum [ "docker" "podman" ]; default = "docker"; };
    containers = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options =
          containerOptions //
          {
            pod = mkOption { type = types.nullOr types.str; default = null; };
            network = mkOption { type = types.nullOr types.str; default = null; };
            volumeSubDir = mkOption { type = types.str; default = name; };
          };
      }));
      default = { };
    };
    pods = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          containers = mkOption {
            type = types.attrsOf (types.submodule { options = containerOptions; });
            default = { };
          };
          volumeSubDir = mkOption { type = types.str; default = name; };
        };
      }));
      default = { };
    };
    volumeBaseDir = mkOption { type = types.str; };
  };
}
