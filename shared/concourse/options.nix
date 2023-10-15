{ lib, ... }:

with lib;

{
  options.nixfiles.concourse = {
    enable = mkOption { type = types.bool; default = false; };
    concourseTag = mkOption { type = types.str; default = "7.8.2"; };
    githubUser = mkOption { type = types.str; default = "barrucadu"; };
    port = mkOption { type = types.int; default = 46498; };
    metricsPort = mkOption { type = types.int; default = 45811; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    workerScratchDir = mkOption { type = types.nullOr types.path; default = null; };
    environmentFile = mkOption { type = types.str; };
  };
}
