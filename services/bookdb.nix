{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.bookdb;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3'

    services:
      bookdb:
        image: ${cfg.image}
        depends_on: [postgres]
        ports: ["127.0.0.1:${toString cfg.port}:3000"]
        environment:
          BOOKDB_PORT: 3000
          BOOKDB_WEB_ROOT: "${cfg.webRoot}"
          BOOKDB_FILE_ROOT: "/bookdb/static"
          BOOKDB_PG_HOST: postgres
          BOOKDB_PG_USERNAME: bookdb
          BOOKDB_PG_PASSWORD: bookdb
          BOOKDB_PG_DB: bookdb
          BOOKDB_READ_ONLY: "${if cfg.readOnly then "true" else "false"}"
        volumes:
          - bookdb_covers:/bookdb/static/covers

      postgres:
        image: postgres:9.6
        environment:
          POSTGRES_DB: bookdb
          POSTGRES_PASSWORD: bookdb
          POSTGRES_USER: bookdb
          PGDATA: /database
        volumes:
          - bookdb_pgdata:/database

    volumes:
      bookdb_covers:
      bookdb_pgdata:
  '';
in
{
  options.services.bookdb = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    port = mkOption { type = types.int; default = 3000; };
    webRoot = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    execStartPre = mkOption { type = types.str; default = ""; };
  };

  config = mkIf cfg.enable {
    systemd.services.bookdb = {
      enable   = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      environment = { COMPOSE_PROJECT_NAME = "bookdb"; };
      serviceConfig = mkMerge [
        (mkIf (cfg.execStartPre != "") { ExecStartPre = "${cfg.execStartPre}"; })
        {
          ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
          ExecStop  = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
          Restart   = "always";
        }
      ];
    };
  };
}
