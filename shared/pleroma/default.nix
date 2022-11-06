{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.pleroma;
  backend = config.nixfiles.oci-containers.backend;
in
{
  # TODO: consider switching to the standard pleroma module
  options.nixfiles.pleroma = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    port = mkOption { type = types.int; default = 4000; };
    pgTag = mkOption { type = types.str; default = "13"; };
    domain = mkOption { type = types.str; };
    faviconPath = mkOption { type = types.nullOr types.path; default = null; };
    instanceName = mkOption { type = types.str; default = cfg.domain; };
    adminEmail = mkOption { type = types.str; default = "mike@barrucadu.co.uk"; };
    notifyEmail = mkOption { type = types.str; default = cfg.adminEmail; };
    secretsFile = mkOption { type = types.str; };
    registry = {
      username = mkOption { type = types.nullOr types.str; default = null; };
      passwordFile = mkOption { type = types.nullOr types.str; default = null; };
      url = mkOption { type = types.nullOr types.str; default = null; };
    };
  };

  config = mkIf cfg.enable {
    nixfiles.oci-containers.containers.pleroma = {
      image = cfg.image;
      login = with cfg.registry; { inherit username passwordFile; registry = url; };
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
      dependsOn = [ "pleroma-db" ];
      network = "pleroma_network";
      ports = [{ host = cfg.port; inner = 4000; }];
      volumes = [
        { name = "uploads"; inner = "/var/lib/pleroma/uploads"; }
        { name = "emojis"; inner = "/var/lib/pleroma/static/emoji/custom"; }
        { host = cfg.secretsFile; inner = "/var/lib/pleroma/secret.exs"; }
      ] ++ (if cfg.faviconPath == null then [ ] else [{ host = pkgs.copyPathToStore cfg.faviconPath; inner = "/var/lib/pleroma/static/favicon.png"; }]);
    };

    nixfiles.oci-containers.containers.pleroma-db = {
      image = "postgres:${cfg.pgTag}";
      environment = {
        "POSTGRES_DB" = "pleroma";
        "POSTGRES_USER" = "pleroma";
        "POSTGRES_PASSWORD" = "pleroma";
      };
      extraOptions = [ "--shm-size=1g" ];
      network = "pleroma_network";
      volumes = [{ name = "pgdata"; inner = "/var/lib/postgresql/data"; }];
      volumeSubDir = "pleroma";
    };

    nixfiles.backups.scripts.pleroma = ''
      ${backend} cp "pleroma:/var/lib/pleroma/uploads" uploads
      ${backend} cp "pleroma:/var/lib/pleroma/static/emoji/custom" emojis
      ${backend} exec -i pleroma-db pg_dump -U pleroma --no-owner pleroma | gzip -9 > dump.sql.gz
    '';
  };
}
