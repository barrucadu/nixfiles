{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.umami;

  yaml = import ./docker-compose-files/umami.docker-compose.nix cfg;
in
{
  options.services.umami = {
    enable = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    hashSalt = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    umamiTag = mkOption { type = types.str; default = "postgresql-latest"; };
  };

  config = mkIf cfg.enable {
    systemd.services.umami = import ./snippets/docker-compose-service.nix {
      inherit lib pkgs yaml;
      composeProjectName = "umami";
      execStartPre = cfg.execStartPre;
    };
  };
}
