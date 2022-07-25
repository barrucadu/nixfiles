{ config, lib, ... }:

with lib;
let
  cfg = config.services.umami;
  backend = config.virtualisation.oci-containers.backend;
in
{
  options.services.umami = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    port = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    umamiTag = mkOption { type = types.str; default = "postgresql-latest"; };
    environmentFile = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.umami = {
      autoStart = true;
      image = "ghcr.io/mikecao/umami:${cfg.umamiTag}";
      environment = {
        "DATABASE_URL" = "postgres://umami:umami@umami-db/umami";
      };
      environmentFiles = [ cfg.environmentFile ];
      extraOptions = [ "--network=umami_network" ];
      dependsOn = [ "umami-db" ];
      ports = [ "127.0.0.1:${toString cfg.port}:3000" ];
    };

    virtualisation.oci-containers.containers.umami-db = {
      autoStart = true;
      image = "postgres:${cfg.postgresTag}";
      environment = {
        "POSTGRES_DB" = "umami";
        "POSTGRES_USER" = "umami";
        "POSTGRES_PASSWORD" = "umami";
      };
      extraOptions = [ "--network=umami_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/pgdata:/var/lib/postgresql/data" ];
    };
    systemd.services."${backend}-umami-db".preStart = "${backend} network create -d bridge umami_network || true";

    services.backups.scripts.umami = ''
      ${backend} exec -i umami-db pg_dump -U umami --no-owner umami | gzip -9 > dump.sql.gz
    '';
  };
}
