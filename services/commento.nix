{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.commento;

  yaml = import ./docker-compose-files/commento.docker-compose.nix cfg;
in
{
  options.services.commento = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    externalUrl = mkOption { type = types.str; };
    commentoTag = mkOption { type = types.str; default = "latest"; };
    forbidNewOwners = mkOption { type = types.bool; default = true; };
    githubKey = mkOption { type = types.nullOr types.str; default = null; };
    githubSecret = mkOption { type = types.nullOr types.str; default = null; };
    googleKey = mkOption { type = types.nullOr types.str; default = null; };
    googleSecret = mkOption { type = types.nullOr types.str; default = null; };
    httpPort = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    twitterKey = mkOption { type = types.nullOr types.str; default = null; };
    twitterSecret = mkOption { type = types.nullOr types.str; default = null; };
  };

  config = mkIf cfg.enable {
    systemd.services.commento = import ./snippets/docker-compose-service.nix {
      inherit lib pkgs yaml;
      composeProjectName = "commento";
      execStartPre = cfg.execStartPre;
    };
  };
}
