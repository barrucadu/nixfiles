{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.wikijs;
  backend = config.nixfiles.oci-containers.backend;
in
{
  options.nixfiles.wikijs = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    wikijsTag = mkOption { type = types.str; default = "2"; };
  };

  config = mkIf cfg.enable {
    nixfiles.oci-containers.containers.wikijs = {
      image = "ghcr.io/requarks/wiki:${cfg.wikijsTag}";
      environment = {
        DB_TYPE = "postgres";
        DB_HOST = "wikijs-db";
        DB_PORT = "5432";
        DB_USER = "wikijs";
        DB_PASS = "wikijs";
        DB_NAME = "wikijs";
      };
      dependsOn = [ "wikijs-db" ];
      network = "wikijs_network";
      ports = [{ host = cfg.port; inner = 3000; }];
    };

    nixfiles.oci-containers.containers.wikijs-db = {
      image = "postgres:${cfg.postgresTag}";
      environment = {
        POSTGRES_DB = "wikijs";
        POSTGRES_USER = "wikijs";
        POSTGRES_PASSWORD = "wikijs";
      };
      network = "wikijs_network";
      volumes = [{ name = "pgdata"; inner = "/var/lib/postgresql/data"; }];
      volumeSubDir = "wikijs";
    };

    nixfiles.backups.scripts.wikijs = ''
      ${backend} exec -i wikijs-db pg_dump -U wikijs --no-owner wikijs | gzip -9 > dump.sql.gz
    '';
  };
}
