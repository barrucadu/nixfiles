{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.bookdb;

  volumeOpts = path: ''
    {
      "driver": "local",
      "driver_opts": {
        "o": "bind",
        "type": "none",
        "device": "${toString cfg.dockerVolumeDir}/${path}",
      }
    }
  '';

  dockerComposeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3'

    services:
      bookdb:
        image: ${cfg.image}
        restart: always
        environment:
          ALLOW_WRITES: "${if cfg.readOnly then "0" else "1"}"
          BASE_URI: "${cfg.baseURI}"
          COVER_DIR: "/bookdb-covers"
          ES_HOST: "http://db:9200"
        networks:
          - bookdb
        ports:
          - "${if cfg.internalHTTP then "127.0.0.1:" else ""}${toString cfg.httpPort}:8888"
        volumes:
          - bookdb_covers:/bookdb-covers
        depends_on:
          - db

      db:
        image: elasticsearch:${cfg.esTag}
        restart: always
        environment:
          - http.host=0.0.0.0
          - discovery.type=single-node
          - ES_JAVA_OPTS=-Xms1g -Xmx1g
        networks:
          - bookdb
        volumes:
          - bookdb_esdata:/usr/share/elasticsearch/data

    networks:
      bookdb:
        external: false

    volumes:
      bookdb_covers: ${if cfg.dockerVolumeDir != /no-path then volumeOpts "covers" else ""}
      bookdb_esdata: ${if cfg.dockerVolumeDir != /no-path then volumeOpts "esdata" else ""}
  '';
in
{
  options.services.bookdb = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    internalHTTP = mkOption { type = types.bool; default = true; };
    esTag = mkOption { type = types.str; default = "7.11.2"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    execStartPre = mkOption { type = types.str; default = ""; };
    dockerVolumeDir = mkOption { type = types.path; default = /no-path; };
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
