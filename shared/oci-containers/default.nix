{ config, lib, ... }:

with lib;
let
  mkPreStart = _name: container: concatStringsSep "\n" [
    (if container.pullOnStart then "${cfg.backend} pull ${container.image}" else "")
    (if container.network != null then "${cfg.backend} network create -d bridge ${container.network} || true" else "")
  ];

  mkPortDef = { host, inner }: "127.0.0.1:${toString host}:${toString inner}";

  mkVolumeDef = container: { name, host, inner }:
    if host != null
    then "${host}:${inner}"
    else "${cfg.volumeBaseDir}/${container.volumeSubDir}/${name}:${inner}";

  mkContainer = _name: container: with container; {
    inherit autoStart cmd dependsOn environment environmentFiles image login;
    extraOptions =
      container.extraOptions ++
      (if container.network != null then [ "--network=${container.network}" ] else [ ]);
    ports = map mkPortDef ports;
    volumes = map (mkVolumeDef container) volumes;
  };

  portOptions = {
    options = {
      host = mkOption { type = types.int; };
      inner = mkOption { type = types.int; };
    };
  };

  volumeOptions = {
    options = {
      name = mkOption { type = types.nullOr types.str; default = null; };
      host = mkOption { type = types.nullOr types.str; default = null; };
      inner = mkOption { type = types.str; };
    };
  };

  cfg = config.nixfiles.oci-containers;
in
{
  options.nixfiles.oci-containers = {
    backend = mkOption { type = types.str; default = "docker"; };
    containers = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
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
          ports = mkOption { type = types.listOf (types.submodule portOptions); default = [ ]; };
          volumes = mkOption { type = types.listOf (types.submodule volumeOptions); default = [ ]; };
          /* new options */
          pullOnStart = mkOption { type = types.bool; default = true; };
          network = mkOption { type = types.nullOr types.str; default = null; };
          volumeSubDir = mkOption { type = types.str; default = name; };
        };
      }));
      default = { };
    };
    volumeBaseDir = mkOption { type = types.str; };
  };

  config = {
    virtualisation.oci-containers.backend = cfg.backend;
    virtualisation.oci-containers.containers = mapAttrs mkContainer cfg.containers;
    systemd.services = mapAttrs' (name: value: nameValuePair "${cfg.backend}-${name}" { preStart = mkPreStart name value; }) cfg.containers;
  };
}
