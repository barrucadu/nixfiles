{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.pleroma;

  faviconPath = if cfg.faviconPath == /no-favicon then /no-favicon else pkgs.copyPathToStore cfg.faviconPath;

  secretsFile = pkgs.writeText "pleroma-secrets.exc" ''
    import Config

    config :pleroma, Pleroma.Web.Endpoint,
      secret_key_base: "${cfg.secretKeyBase}",
      signing_salt: "${cfg.signingSalt}"

    config :web_push_encryption, :vapid_details,
      public_key: "${cfg.webPushPublicKey}",
      private_key: "${cfg.webPushPrivateKey}"
  '';

  yaml = import ./docker-compose-files/pleroma.docker-compose.nix {
    inherit faviconPath secretsFile;
    dockerVolumeDir = cfg.dockerVolumeDir;
    domain = cfg.domain;
    image = cfg.image;
    adminEmail = cfg.adminEmail;
    httpPort = cfg.httpPort;
    instanceName = cfg.instanceName;
    internalHTTP = cfg.internalHTTP;
    notifyEmail = cfg.notifyEmail;
    pgTag = cfg.pgTag;
  };

  dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;

in
{
  options.services.pleroma = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 4000; };
    internalHTTP = mkOption { type = types.bool; default = true; };
    pgTag = mkOption { type = types.str; default = "13"; };
    execStartPre = mkOption { type = types.str; default = ""; };
    domain = mkOption { type = types.str; };
    faviconPath = mkOption { type = types.path; default = /no-favicon; };
    instanceName = mkOption { type = types.str; default = cfg.domain; };
    adminEmail = mkOption { type = types.str; default = "mike@barrucadu.co.uk"; };
    notifyEmail = mkOption { type = types.str; default = cfg.adminEmail; };
    secretKeyBase = mkOption { type = types.str; };
    signingSalt = mkOption { type = types.str; };
    webPushPublicKey = mkOption { type = types.str; };
    webPushPrivateKey = mkOption { type = types.str; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    systemd.services.pleroma = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      environment = { COMPOSE_PROJECT_NAME = "pleroma"; };
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
