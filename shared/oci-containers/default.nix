# An abstraction over running containers as systemd units, enforcing some good
# practices:
#
# - Container DNS behaves the same under docker and podman.
# - Ports are exposed on `127.0.0.1`, rather than `0.0.0.0`.
# - Volumes are backed up by bind-mounts to the host filesystem.
#
# Switching between using docker or podman for the container runtime should be
# totally transparent.
#
# If the `erase-your-darlings` module is enabled, stores volume bind-mounts on
# the persistent volume.
{ config, lib, pkgs, ... }:

# TODO: ensure podman containers run as a non-root user

with lib;
let
  mkPortDef = { host, inner }: "127.0.0.1:${toString host}:${toString inner}";

  mkVolumeDef = container: { name, host, inner }:
    if host != null
    then "${host}:${inner}"
    else "${cfg.volumeBaseDir}/${container.volumeSubDir}/${name}:${inner}";

  shouldPreStart = _name: container: container.pullOnStart;
  mkPreStart = name: container: nameValuePair "${cfg.backend}-${name}" {
    preStart = if container.pullOnStart then "${cfg.backend} pull ${container.image}" else "";
  };

  shouldNetworkService = _name: container: container.network != null;
  mkNetworkService = _name: container:
    let package = if cfg.backend == "docker" then pkgs.docker else pkgs.podman;
    in nameValuePair "${cfg.backend}-net-${container.network}" {
      description = "Manage the ${container.network} network for ${cfg.backend}";
      preStart = "${package}/bin/${cfg.backend} network rm ${container.network} || true";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${package}/bin/${cfg.backend} network create -d bridge ${container.network}";
        ExecStop = "${package}/bin/${cfg.backend} network rm ${container.network}";
        RemainAfterExit = "yes";
      };
    };

  mkPodService = name: pod:
    let
      package = if cfg.backend == "podman" then pkgs.podman else throw "mkPodService only supports podman";
      aliases = map (cn: "${name}-${cn}") (attrNames pod.containers);
      ports = concatLists (catAttrs "ports" (attrValues pod.containers));
    in
    nameValuePair "${cfg.backend}-pod-${name}" {
      description = "Manage the ${name} pod for ${cfg.backend}";
      preStart = "${package}/bin/${cfg.backend} pod rm --force --ignore ${name} || true";
      serviceConfig = {
        Type = "oneshot";
        ExecStart =
          let args = map (n: "--network-alias=${n}") aliases ++ map (pd: "-p ${mkPortDef pd}") ports;
          in "${package}/bin/${cfg.backend} pod create ${concatStringsSep " " args} ${name}";
        ExecStop = "${package}/bin/${cfg.backend} pod rm ${name}";
        RemainAfterExit = "yes";
      };
    };

  mkContainer = _name: container: with container;
    let
      hasNetwork = container.network != null;
      hasPod = container.pod != null;
    in
    {
      inherit autoStart cmd environment environmentFiles image login;
      dependsOn =
        container.dependsOn ++
        (if hasNetwork then [ "net-${container.network}" ] else [ ]) ++
        (if hasPod then [ "pod-${container.pod}" ] else [ ]);
      extraOptions =
        container.extraOptions ++
        (if hasNetwork then [ "--network=${container.network}" ] else [ ]) ++
        (if hasPod then [ "--pod=${container.pod}" ] else [ ]);
      /* ports are defined at the pod level */
      ports = if hasPod then [ ] else map mkPortDef ports;
      volumes = map (mkVolumeDef container) volumes;
    };

  cfg = config.nixfiles.oci-containers;

  allContainers =
    let
      mkPodContainer = podName: pod: containerName: container: nameValuePair "${podName}-${containerName}" (
        container //
        {
          network = if cfg.backend == "docker" then podName else null;
          pod = if cfg.backend == "docker" then null else podName;
          volumeSubDir = pod.volumeSubDir;
        }
      );
    in
    concatMapAttrs (podName: pod: mapAttrs' (mkPodContainer podName pod) pod.containers) cfg.pods;
in
{
  imports = [
    ./options.nix
  ];

  config = {
    virtualisation.${cfg.backend}.autoPrune.enable = true;
    virtualisation.oci-containers.backend = cfg.backend;
    virtualisation.oci-containers.containers = mapAttrs mkContainer allContainers;
    systemd.services = mkMerge [
      (mapAttrs' mkPreStart (filterAttrs shouldPreStart allContainers))
      (mapAttrs' mkNetworkService (filterAttrs shouldNetworkService allContainers))
      (if cfg.backend == "podman" then mapAttrs' mkPodService cfg.pods else { })
    ];
  };
}
