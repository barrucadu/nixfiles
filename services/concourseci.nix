{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.concourseci;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3'

    services:
      concourse:
        image: concourse/concourse
        command: quickstart
        privileged: true
        depends_on: [postgres, registry]
        ports: ["${toString cfg.port}:8080"]
        environment:
          CONCOURSE_POSTGRES_HOST: postgres
          CONCOURSE_POSTGRES_USER: concourse
          CONCOURSE_POSTGRES_PASSWORD: concourse
          CONCOURSE_POSTGRES_DATABASE: concourse
          CONCOURSE_EXTERNAL_URL: "${if cfg.useSSL then "https" else "http"}://${cfg.virtualhost}"
          CONCOURSE_MAIN_TEAM_GITHUB_USER: "${cfg.githubUser}"
          CONCOURSE_GITHUB_CLIENT_ID: "${cfg.githubClientId}"
          CONCOURSE_GITHUB_CLIENT_SECRET: "${cfg.githubClientSecret}"
        networks:
          - ci

      postgres:
        image: postgres
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
        image: registry
        networks:
          ci:
            ipv4_address: "${cfg.registryIP}"
            aliases: [ci-registry]

    networks:
      ci:
        ipam:
          driver: default
          config:
            - subnet: ${cfg.subnet}

    volumes:
      pgdata:
  '';
in
{
  options.services.concourseci = {
    port = mkOption { type = types.int; default = 3001; };
    useSSL = mkOption { type = types.bool; default = true; };
    forceSSL = mkOption { type = types.bool; default = true; };
    virtualhost = mkOption { type = types.str; };
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

    services.nginx.virtualHosts."${cfg.virtualhost}" = {
      enableACME = cfg.useSSL;
      forceSSL = cfg.useSSL && cfg.forceSSL;
      locations."/" = {
        proxyPass = "http://localhost:${toString cfg.port}/";
        proxyWebsockets = true;
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
