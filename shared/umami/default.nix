{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.umami;
  backend = config.nixfiles.oci-containers.backend;
in
{
  options.nixfiles.umami = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    umamiTag = mkOption { type = types.str; default = "postgresql-latest"; };
    environmentFile = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    nixfiles.oci-containers.containers.umami = {
      image = "ghcr.io/mikecao/umami:${cfg.umamiTag}";
      environment = {
        "DATABASE_URL" = "postgres://umami:umami@umami-db/umami";
      };
      environmentFiles = [ cfg.environmentFile ];
      dependsOn = [ "umami-db" ];
      network = "umami_network";
      ports = [{ host = cfg.port; inner = 3000; }];
    };

    nixfiles.oci-containers.containers.umami-db = {
      image = "postgres:${cfg.postgresTag}";
      environment = {
        "POSTGRES_DB" = "umami";
        "POSTGRES_USER" = "umami";
        "POSTGRES_PASSWORD" = "umami";
      };
      network = "umami_network";
      volumes = [{ name = "pgdata"; inner = "/var/lib/postgresql/data"; }];
      volumeSubDir = "umami";
    };

    nixfiles.backups.scripts.umami = ''
      ${backend} exec -i umami-db pg_dump -U umami --no-owner umami | gzip -9 > dump.sql.gz
    '';
  };
}
