{ config, lib, ... }:

with lib;
let
  cfg = config.services.gitea;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  # TODO: consider switching to the standard gitea module
  disabledModules = [
    "services/misc/gitea.nix"
  ];

  options.services.gitea = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    giteaTag = mkOption { type = types.str; default = "1.13.4"; };
    httpPort = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    sshPort = mkOption { type = types.int; default = 222; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.gitea = {
      autoStart = true;
      image = "gitea/gitea:${cfg.giteaTag}";
      environment = {
        "APP_NAME" = "barrucadu.dev git";
        "RUN_MODE" = "prod";
        "ROOT_URL" = "https://git.barrucadu.dev";
        "SSH_DOMAIN" = "barrucadu.dev";
        "SSH_PORT" = toString cfg.sshPort;
        "SSH_LISTEN_PORT" = "22";
        "HTTP_PORT" = "3000";
        "DB_TYPE" = "postgres";
        "DB_HOST" = "gitea-db:5432";
        "DB_NAME" = "gitea";
        "DB_USER" = "gitea";
        "DB_PASSWD" = "gitea";
        "USER_UID" = "1000";
        "USER_GID" = "1000";
      };
      extraOptions = [ "--network=gitea_network" ];
      dependsOn = [ "gitea-db" ];
      ports = [
        "127.0.0.1:${toString cfg.httpPort}:3000"
        "${toString cfg.sshPort}:22"
      ];
      volumes = [ "${toString cfg.dockerVolumeDir}/data:/data" ];
    };
    systemd.services."${backend}-gitea" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.gitea-db = {
      autoStart = true;
      image = "postgres:${cfg.postgresTag}";
      environment = {
        "POSTGRES_DB" = "gitea";
        "POSTGRES_USER" = "gitea";
        "POSTGRES_PASSWORD" = "gitea";
      };
      extraOptions = [ "--network=gitea_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/pgdata:/var/lib/postgresql/data" ];
    };
    systemd.services."${backend}-gitea-db" = {
      preStart = "${backend} network create -d bridge gitea_network || true";
      serviceConfig = serviceConfigForContainerLogging;
    };
  };
}
