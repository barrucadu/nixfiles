{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.nupleroma;

  secretsFile = pkgs.writeText "pleroma-secrets.exc" ''
    import Config

    config :pleroma, Pleroma.Web.Endpoint,
      secret_key_base: "${cfg.secretKeyBase}",
      signing_salt: "${cfg.signingSalt}"

    config :web_push_encryption, :vapid_details,
      public_key: "${cfg.webPushPublicKey}",
      private_key: "${cfg.webPushPrivateKey}"
  '';

  dockerComposeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3'

    services:
      pleroma:
        image: ${cfg.image}
        restart: always
        environment:
          DOMAIN: "${cfg.domain}"
          INSTANCE_NAME: "${cfg.instanceName}"
          ADMIN_EMAIL: "${cfg.adminEmail}"
          NOTIFY_EMAIL: "${cfg.notifyEmail}"
          DB_USER: "pleroma"
          DB_PASS: "pleroma"
          DB_NAME: "pleroma"
          DB_HOST: "db"
        networks:
          - pleroma
        ports:
          - "${if cfg.internalHTTP then "127.0.0.1:" else ""}${toString cfg.httpPort}:4000"
        volumes:
          - pleroma_uploads:/var/lib/pleroma/uploads
          - pleroma_emojis:/var/lib/pleroma/static/emoji/custom
          - ${secretsFile}:/var/lib/pleroma/secret.exs
        depends_on:
          - db

      db:
        image: postgres:${cfg.pgTag}
        restart: always
        environment:
          POSTGRES_USER: pleroma
          POSTGRES_PASSWORD: pleroma
          POSTGRES_DB: pleroma
        networks:
          - pleroma
        volumes:
          - pleroma_pgdata:/var/lib/postgresql/data

    networks:
      pleroma:
        external: false

    volumes:
      pleroma_uploads:
      pleroma_emojis:
      pleroma_pgdata:
  '';

in
{
  options.services.nupleroma = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 4000; };
    internalHTTP = mkOption { type = types.bool; default = true; };
    pgTag = mkOption { type = types.str; default = "13"; };
    execStartPre = mkOption { type = types.str; default = ""; };
    domain = mkOption { type = types.str; };
    instanceName = mkOption { type = types.str; default = cfg.domain; };
    adminEmail = mkOption { type = types.str; default = "mike@barrucadu.co.uk"; };
    notifyEmail = mkOption { type = types.str; default = cfg.adminEmail; };
    secretKeyBase = mkOption { type = types.str; };
    signingSalt = mkOption { type = types.str; };
    webPushPublicKey = mkOption { type = types.str; };
    webPushPrivateKey = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    systemd.services.nupleroma = {
      enable   = true;
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      environment = { COMPOSE_PROJECT_NAME = "pleroma"; };
      serviceConfig = mkMerge [
        (mkIf (cfg.execStartPre != "") { ExecStartPre = "${cfg.execStartPre}"; })
        {
          ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
          ExecStop  = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
          Restart   = "always";
        }
      ];
    };
  };
}