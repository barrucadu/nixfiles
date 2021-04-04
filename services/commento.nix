{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.commento;

  yaml = import ./docker-compose-files/commento.docker-compose.nix cfg;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;
in
{
  options.services.commento = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    externalUrl = mkOption { type = types.str; };
    commentoTag = mkOption { type = types.str; default = "latest"; };
    forbidNewOwners = mkOption { type = types.bool; default = true; };
    githubKey = mkOption { type = types.str; default = null; };
    githubSecret = mkOption { type = types.str; default = null; };
    googleKey = mkOption { type = types.str; default = null; };
    googleSecret = mkOption { type = types.str; default = null; };
    httpPort = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    twitterKey = mkOption { type = types.str; default = null; };
    twitterSecret = mkOption { type = types.str; default = null; };
  };

  config = mkIf cfg.enable {
    systemd.services.commento = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      environment = { COMPOSE_PROJECT_NAME = "commento"; };
      serviceConfig = {
        ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
        ExecStop = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
        Restart = "always";
      };
    };
  };
}
