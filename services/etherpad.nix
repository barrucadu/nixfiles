{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.etherpad;

  yaml = import ./docker-compose-files/etherpad.docker-compose.nix cfg;
in
{
  options.services.etherpad = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    pgTag = mkOption { type = types.str; default = "13"; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    systemd.services.etherpad = import ./snippets/docker-compose-service.nix {
      inherit lib pkgs yaml;
      composeProjectName = "etherpad";
      execStartPre = cfg.execStartPre;
    };
  };
}
