{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.gitea;

  yaml = import ./docker-compose-files/gitea.docker-compose.nix cfg;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;
in
{
  # TODO: consider switching to the standard gitea module
  disabledModules = [
    "services/misc/gitea.nix"
  ];

  options.services.gitea = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    giteaTag = mkOption { type = types.str; default = "1.13.4"; };
    httpPort = mkOption { type = types.int; default = 3000; };
    internalHTTP = mkOption { type = types.bool; default = true; };
    internalSSH = mkOption { type = types.bool; default = false; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    sshPort = mkOption { type = types.int; default = 222; };
  };

  config = mkIf cfg.enable {
    systemd.services.gitea = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      environment = { COMPOSE_PROJECT_NAME = "gitea"; };
      serviceConfig = {
        ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
        ExecStop = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
        Restart = "always";
      };
    };
  };
}
