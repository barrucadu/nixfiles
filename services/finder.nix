{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.finder;

  yaml = import ./docker-compose-files/finder.docker-compose.nix cfg;
in
{
  options.services.finder = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "7.11.2"; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    dockerVolumeDir = mkOption { type = types.path; };
    mangaDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    systemd.services.finder = import ./snippets/docker-compose-service.nix {
      inherit lib pkgs yaml;
      composeProjectName = "finder";
      execStartPre = cfg.execStartPre;
    };
  };
}
