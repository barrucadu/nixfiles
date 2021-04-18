{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.concourse;

  yaml = import ./docker-compose-files/concourse.docker-compose.nix cfg;
in
{
  options.services.concourse = {
    enable = mkOption { type = types.bool; default = false; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    dockerVolumeDir = mkOption { type = types.path; };
    githubClientId = mkOption { type = types.str; };
    githubClientSecret = mkOption { type = types.str; };
    concourseTag = mkOption { type = types.str; default = "7.1"; };
    enableSSM = mkOption { type = types.bool; default = false; };
    githubUser = mkOption { type = types.str; default = "barrucadu"; };
    httpPort = mkOption { type = types.int; default = 3001; };
    metricsPort = mkOption { type = types.int; default = 9001; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    ssmAccessKey = mkOption { type = types.nullOr types.str; default = null; };
    ssmRegion = mkOption { type = types.str; default = "eu-west-1"; };
    ssmSecretKey = mkOption { type = types.nullOr types.str; default = null; };
    workerScratchDir = mkOption { type = types.nullOr types.path; default = null; };
  };

  config = mkIf cfg.enable {
    systemd.services.concourse = import ./snippets/docker-compose-service.nix {
      inherit lib pkgs yaml;
      composeProjectName = "concourse";
      execStartPre = cfg.execStartPre;
    };
  };
}
