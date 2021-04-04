{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.bookdb;

  yaml = import ./docker-compose-files/bookdb.docker-compose.nix cfg;
in
{
  options.services.bookdb = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "7.11.2"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    systemd.services.bookdb = import ./snippets/docker-compose-service.nix {
      inherit lib pkgs yaml;
      composeProjectName = "bookdb";
      execStartPre = cfg.execStartPre;
    };
  };
}
