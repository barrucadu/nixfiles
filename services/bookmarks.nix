{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.bookmarks;

  yaml = import ./docker-compose-files/bookmarks.docker-compose.nix cfg;

  dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;
in
{
  options.services.bookmarks = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "7.11.2"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    execStartPre = mkOption { type = types.str; default = ""; };
    youtubeApiKey = mkOption { type = types.str; default = ""; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    systemd.services.bookmarks = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      environment = { COMPOSE_PROJECT_NAME = "bookmarks"; };
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
