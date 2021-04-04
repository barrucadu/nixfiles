{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.etherpad;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3'

    services:
      etherpad:
        image: ${cfg.image}
        restart: always
        environment:
          DB_TYPE: "postgres"
          DB_HOST: "db"
          DB_PORT: "5432"
          DB_NAME: "etherpad"
          DB_USER: "etherpad"
          DB_PASS: "etherpad"
          TRUST_PROXY: "true"
        networks:
          - etherpad
        ports:
          - "${if cfg.internalHTTP then "127.0.0.1:" else ""}${toString cfg.httpPort}:9001"
        depends_on:
          - db

      db:
        image: postgres:${cfg.pgTag}
        restart: always
        environment:
          POSTGRES_USER: etherpad
          POSTGRES_PASSWORD: etherpad
          POSTGRES_DB: etherpad
        networks:
          - etherpad
        volumes:
          - ${toString cfg.dockerVolumeDir}/pgdata:/var/lib/postgresql/data

    networks:
      etherpad:
        external: false
  '';
in
{
  options.services.etherpad = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    internalHTTP = mkOption { type = types.bool; default = true; };
    pgTag = mkOption { type = types.str; default = "13"; };
    execStartPre = mkOption { type = types.str; default = ""; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    systemd.services.etherpad = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      environment = { COMPOSE_PROJECT_NAME = "etherpad"; };
      serviceConfig = mkMerge [
        (mkIf (cfg.execStartPre != "") { ExecStartPre = "${cfg.execStartPre}"; })
        {
          ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
          ExecStop = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
          Restart = "always";
        }
      ];
    };
  };
}
