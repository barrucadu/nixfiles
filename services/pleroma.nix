{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.pleroma;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  # TODO: consider switching to the standard pleroma module
  disabledModules = [
    "services/networking/pleroma.nix"
  ];

  options.services.pleroma = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 4000; };
    pgTag = mkOption { type = types.str; default = "13"; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    domain = mkOption { type = types.str; };
    faviconPath = mkOption { type = types.nullOr types.path; default = null; };
    instanceName = mkOption { type = types.str; default = cfg.domain; };
    adminEmail = mkOption { type = types.str; default = "mike@barrucadu.co.uk"; };
    notifyEmail = mkOption { type = types.str; default = cfg.adminEmail; };
    secretsFile = mkOption { type = types.str; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.pleroma = {
      autoStart = true;
      image = cfg.image;
      environment = {
        "DOMAIN" = cfg.domain;
        "INSTANCE_NAME" = cfg.instanceName;
        "ADMIN_EMAIL" = cfg.adminEmail;
        "NOTIFY_EMAIL" = cfg.notifyEmail;
        "DB_USER" = "pleroma";
        "DB_PASS" = "pleroma";
        "DB_NAME" = "pleroma";
        "DB_HOST" = "pleroma-db";
      };
      extraOptions = [ "--network=pleroma_network" ];
      dependsOn = [ "pleroma-db" ];
      ports = [ "127.0.0.1:${toString cfg.httpPort}:4000" ];
      volumes = [
        "${toString cfg.dockerVolumeDir}/uploads:/var/lib/pleroma/uploads"
        "${toString cfg.dockerVolumeDir}/emojis:/var/lib/pleroma/static/emoji/custom"
        "${cfg.secretsFile}:/var/lib/pleroma/secret.exs"
      ] ++ (if cfg.faviconPath == null then [ ] else [ "${pkgs.copyPathToStore cfg.faviconPath}:/var/lib/pleroma/static/favicon.png" ]);
    };
    systemd.services."${backend}-pleroma" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.pleroma-db = {
      autoStart = true;
      image = "postgres:${cfg.pgTag}";
      environment = {
        "POSTGRES_DB" = "pleroma";
        "POSTGRES_USER" = "pleroma";
        "POSTGRES_PASSWORD" = "pleroma";
      };
      extraOptions = [ "--network=pleroma_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/pgdata:/var/lib/postgresql/data" ];
    };
    systemd.services."${backend}-pleroma-db" = {
      preStart = "${backend} network create -d bridge pleroma_network || true";
      serviceConfig = serviceConfigForContainerLogging;
    };
  };
}
