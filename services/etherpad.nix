{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.etherpad;

  yaml = import ./docker-compose-files/etherpad.docker-compose.nix cfg;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;
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
