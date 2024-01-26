# [umami][] is a web analytics tool.
#
# umami uses a containerised postgres database.
#
# **Backups:** the postgres database.
#
# [umami]: https://umami.is/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.umami;
  backend = config.nixfiles.oci-containers.backend;
  backendPkg = if backend == "docker" then pkgs.docker else pkgs.podman;
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

    nixfiles.restic-backups.backups.umami = {
      prepareCommand = ''
        /run/wrappers/bin/sudo ${backendPkg}/bin/${backend} exec -i umami-db pg_dump -U umami --no-owner -Fc umami > postgres.dump
      '';
      paths = [
        "postgres.dump"
      ];
    };
    nixfiles.restic-backups.sudoRules = [
      { command = "${backendPkg}/bin/${backend} exec -i umami-db pg_dump -U umami --no-owner -Fc umami"; }
    ];

    nixfiles.backups.scripts.umami = ''
      /run/wrappers/bin/sudo ${backendPkg}/bin/${backend} exec -i umami-db pg_dump -U umami --no-owner umami | gzip -9 > dump.sql.gz
    '';
    nixfiles.backups.sudoRules = [
      { command = "${backendPkg}/bin/${backend} exec -i umami-db pg_dump -U umami --no-owner umami"; }
    ];
  };
}
