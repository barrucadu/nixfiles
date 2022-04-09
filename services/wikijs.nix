{ config, lib, ... }:

with lib;
let
  cfg = config.services.wikijs;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  options.services.wikijs = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    httpPort = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    wikijsTag = mkOption { type = types.str; default = "2"; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.wikijs = {
      autoStart = true;
      image = "ghcr.io/requarks/wiki:${cfg.wikijsTag}";
      environment = {
        DB_TYPE = "postgres";
        DB_HOST = "wikijs-db";
        DB_PORT = "5432";
        DB_USER = "wikijs";
        DB_PASS = "wikijs";
        DB_NAME = "wikijs";
      };
      extraOptions = [ "--network=wikijs_network" ];
      dependsOn = [ "wikijs-db" ];
      ports = [ "127.0.0.1:${toString cfg.httpPort}:3000" ];
    };
    systemd.services."${backend}-wikijs" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.wikijs-db = {
      autoStart = true;
      image = "postgres:${cfg.postgresTag}";
      environment = {
        POSTGRES_DB = "wikijs";
        POSTGRES_USER = "wikijs";
        POSTGRES_PASSWORD = "wikijs";
      };
      extraOptions = [ "--network=wikijs_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/pgdata:/var/lib/postgresql/data" ];
    };
    systemd.services."${backend}-wikijs-db" = {
      preStart = "${backend} network create -d bridge wikijs_network || true";
      serviceConfig = serviceConfigForContainerLogging;
    };
  };
}
