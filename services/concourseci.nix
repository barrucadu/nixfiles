{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.concourseci;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3'

    services:
      concourse:
        image: concourse/concourse:5.7
        command: quickstart
        privileged: true
        depends_on: [postgres, registry]
        ports: ["127.0.0.1:${toString cfg.port}:8080"]
        environment:
          CONCOURSE_POSTGRES_HOST: postgres
          CONCOURSE_POSTGRES_USER: concourse
          CONCOURSE_POSTGRES_PASSWORD: concourse
          CONCOURSE_POSTGRES_DATABASE: concourse
          CONCOURSE_EXTERNAL_URL: "https://${cfg.domain}"
          CONCOURSE_MAIN_TEAM_GITHUB_USER: "${cfg.githubUser}"
          CONCOURSE_GITHUB_CLIENT_ID: "${cfg.githubClientId}"
          CONCOURSE_GITHUB_CLIENT_SECRET: "${cfg.githubClientSecret}"
          CONCOURSE_LOG_LEVEL: error
          CONCOURSE_GARDEN_LOG_LEVEL: error
        networks:
          - ci

      postgres:
        image: postgres:9.6
        environment:
          POSTGRES_DB: concourse
          POSTGRES_PASSWORD: concourse
          POSTGRES_USER: concourse
          PGDATA: /database
        networks:
          - ci
        volumes:
          - pgdata:/database

      registry:
        image: registry:2.7
        networks:
          ci:
            ipv4_address: "${cfg.registryIP}"
            aliases: [ci-registry]
        volumes:
          - regdata:/var/lib/registry

    networks:
      ci:
        ipam:
          driver: default
          config:
            - subnet: ${cfg.subnet}

    volumes:
      pgdata:
      regdata:
  '';
in
{
  options.services.concourseci = {
    port = mkOption { type = types.int; default = 3001; };
    domain = mkOption { type = types.str; };
    githubUser = mkOption { type = types.str; default = "barrucadu"; };
    githubClientId =  mkOption { type = types.str; };
    githubClientSecret =  mkOption { type = types.str; };
    sshPublicKeys = mkOption { type = types.listOf types.str; };
    subnet = mkOption { type = types.str; default = "172.21.0.0/16"; };
    registryIP = mkOption { type = types.str; default = "172.21.0.254"; };
  };

  config = {
    networking.hosts."${cfg.registryIP}" = [ "ci-registry" ];
    virtualisation.docker.extraOptions = "--insecure-registry=ci-registry:5000";

    systemd.services.concourseci = {
      enable   = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
        ExecStop  = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' down";
        Restart   = "always";
        User      = "concourseci";
        WorkingDirectory = "/srv/concourseci";
      };
    };

    users.extraUsers.concourseci = {
      home = "/srv/concourseci";
      createHome = true;
      isSystemUser = true;
      extraGroups = [ "docker" ];
      openssh.authorizedKeys.keys = cfg.sshPublicKeys;
      shell = pkgs.bashInteractive;
    };
  };
}
