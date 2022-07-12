{ config, lib, ... }:

with lib;
let
  cfg = config.services.commento;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  options.services.commento = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    externalUrl = mkOption { type = types.str; };
    commentoTag = mkOption { type = types.str; default = "latest"; };
    forbidNewOwners = mkOption { type = types.bool; default = true; };
    httpPort = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    environmentFile = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.commento = {
      autoStart = true;
      image = "registry.gitlab.com/commento/commento:${cfg.commentoTag}";
      environment = {
        "COMMENTO_ORIGIN" = cfg.externalUrl;
        "COMMENTO_PORT" = "8080";
        "COMMENTO_POSTGRES" = "postgres://commento:commento@commento-db/commento?sslmode=disable";
        "COMMENTO_FORBID_NEW_OWNERS" = if cfg.forbidNewOwners then "true" else "false";
      };
      environmentFiles = [ cfg.environmentFile ];
      extraOptions = [ "--network=commento_network" ];
      dependsOn = [ "commento-db" ];
      ports = [ "127.0.0.1:${toString cfg.httpPort}:8080" ];
    };
    systemd.services."${backend}-commento" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.commento-db = {
      autoStart = true;
      image = "postgres:${cfg.postgresTag}";
      environment = {
        "POSTGRES_DB" = "commento";
        "POSTGRES_USER" = "commento";
        "POSTGRES_PASSWORD" = "commento";
      };
      extraOptions = [ "--network=commento_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/pgdata:/var/lib/postgresql/data" ];
    };
    systemd.services."${backend}-commento-db" = {
      preStart = "${backend} network create -d bridge commento_network || true";
      serviceConfig = serviceConfigForContainerLogging;
    };
  };
}
