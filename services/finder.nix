{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.finder;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3'

    services:
      finder:
        image: ${cfg.image}
        restart: always
        environment:
          DATA_DIR: "/data"
          ES_HOST: "http://db:9200"
        networks:
          - finder
        ports:
          - "${if cfg.internalHTTP then "127.0.0.1:" else ""}${toString cfg.httpPort}:8888"
        volumes:
          - /srv/share/manga:/data
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
          - finder
        volumes:
          - finder_esdata:/usr/share/elasticsearch/data

    networks:
      finder:
        external: false

    volumes:
      finder_covers:
      finder_esdata:
  '';
in
{
  options.services.finder = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    internalHTTP = mkOption { type = types.bool; default = true; };
    esTag = mkOption { type = types.str; default = "7.6.2"; };
    execStartPre = mkOption { type = types.str; default = ""; };
  };

  config = mkIf cfg.enable {
    systemd.services.finder = {
      enable   = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      environment = { COMPOSE_PROJECT_NAME = "finder"; };
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