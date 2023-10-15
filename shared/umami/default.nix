# [umami][] is a web analytics tool.
#
# umami uses a containerised postgres database.
#
# If the `backups` module is enabled, adds a script to backup the database.
#
# If the `erase-your-darlings` module is enabled, stores its data on the
# persistent volume.
#
# [umami]: https://umami.is/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.umami;
  backend = config.nixfiles.oci-containers.backend;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    nixfiles.oci-containers.pods.umami = {
      containers = {
        web = {
          image = "ghcr.io/mikecao/umami:${cfg.umamiTag}";
          environment = {
            "DATABASE_URL" = if backend == "docker" then "postgres://umami:umami@umami-db/umami" else "postgres://umami:umami@localhost/umami";
          };
          environmentFiles = [ cfg.environmentFile ];
          dependsOn = [ "umami-db" ];
          ports = [{ host = cfg.port; inner = 3000; }];
        };
        db = {
          image = "postgres:${cfg.postgresTag}";
          environment = {
            "POSTGRES_DB" = "umami";
            "POSTGRES_USER" = "umami";
            "POSTGRES_PASSWORD" = "umami";
          };
          volumes = [{ name = "pgdata"; inner = "/var/lib/postgresql/data"; }];
        };
      };
    };

    nixfiles.backups.scripts.umami = ''
      /run/wrappers/bin/sudo ${backend} exec -i umami-db pg_dump -U umami --no-owner umami | gzip -9 > dump.sql.gz
    '';
    nixfiles.backups.sudoRules = [
      {
        command =
          let pkg = if backend == "docker" then pkgs.docker else pkgs.podman;
          in "${pkg}/bin/${backend} exec -i umami-db pg_dump -U umami --no-owner umami";
      }
    ];
  };
}
