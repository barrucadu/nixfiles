{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.concourse;

  yaml = import ./docker-compose-files/concourse.docker-compose.nix cfg;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;
in
{
  options.services.concourse = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    githubClientId = mkOption { type = types.str; };
    githubClientSecret = mkOption { type = types.str; };
    concourseTag = mkOption { type = types.str; default = "7.1"; };
    enableSSM = mkOption { type = types.bool; default = false; };
    githubUser = mkOption { type = types.str; default = "barrucadu"; };
    httpPort = mkOption { type = types.int; default = 3001; };
    internalHTTP = mkOption { type = types.bool; default = true; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    ssmAccessKey = mkOption { type = types.str; default = ""; };
    ssmRegion = mkOption { type = types.str; default = "eu-west-1"; };
    ssmSecretKey = mkOption { type = types.str; default = ""; };
  };

  config = mkIf cfg.enable {
    systemd.services.concourse = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      environment = { COMPOSE_PROJECT_NAME = "concourse"; };
      serviceConfig = {
        ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
        ExecStop = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
        Restart = "always";
      };
    };
  };
}
