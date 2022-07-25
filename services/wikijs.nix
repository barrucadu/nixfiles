{ config, lib, ... }:

with lib;
let
  cfg = config.services.wikijs;
  backend = config.virtualisation.oci-containers.backend;
in
{
  options.services.wikijs = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    port = mkOption { type = types.int; default = 3000; };
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
      ports = [ "127.0.0.1:${toString cfg.port}:3000" ];
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
    systemd.services."${backend}-wikijs-db".preStart = "${backend} network create -d bridge wikijs_network || true";

    modules.backupScripts.scripts.wikijs = ''
      ${backend} exec -i wikijs-db pg_dump -U wikijs --no-owner wikijs | gzip -9 > dump.sql.gz
    '';
  };
}
