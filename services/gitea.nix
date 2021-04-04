{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.gitea;

  yaml = import ./docker-compose-files/gitea.docker-compose.nix cfg;
in
{
  # TODO: consider switching to the standard gitea module
  disabledModules = [
    "services/misc/gitea.nix"
  ];

  options.services.gitea = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    giteaTag = mkOption { type = types.str; default = "1.13.4"; };
    httpPort = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    sshPort = mkOption { type = types.int; default = 222; };
  };

  config = mkIf cfg.enable {
    systemd.services.gitea = import ./snippets/docker-compose-service.nix {
      inherit lib pkgs yaml;
      composeProjectName = "gitea";
      execStartPre = cfg.execStartPre;
    };
  };
}
