{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.pleroma;
  backend = config.nixfiles.oci-containers.backend;
in
{
  imports = [ ./erase-your-darlings.nix ];

  options.nixfiles.pleroma = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 4000; };
    pgTag = mkOption { type = types.str; default = "13"; };
    domain = mkOption { type = types.str; };
    faviconPath = mkOption { type = types.nullOr types.path; default = null; };
    instanceName = mkOption { type = types.str; default = cfg.domain; };
    adminEmail = mkOption { type = types.str; default = "mike@barrucadu.co.uk"; };
    notifyEmail = mkOption { type = types.str; default = cfg.adminEmail; };
    allowRegistration = mkOption { type = types.bool; default = false; };
    secretsFile = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    services.pleroma.enable = true;
    services.pleroma.configs = [
      ''
        import Config

        config :pleroma, Pleroma.Web.Endpoint,
          url: [host: System.fetch_env!("DOMAIN"), scheme: "https", port: 443],
          http: [ip: {127, 0, 0, 1}, port: System.fetch_env!("PORT") |> String.to_integer]

        config :pleroma, :instance,
          name: System.fetch_env!("INSTANCE_NAME"),
          email: System.fetch_env!("ADMIN_EMAIL"),
          notify_email: System.fetch_env!("NOTIFY_EMAIL"),
          limit: 5000,
          registrations_open: System.fetch_env!("ALLOW_REGISTRATION") |> String.to_atom,
          healthcheck: true

        config :pleroma, Pleroma.Repo,
          adapter: Ecto.Adapters.Postgres,
          username: "pleroma",
          password: "pleroma",
          database: "pleroma",
          socket_dir: "/var/run/pleroma/db/",
          pool_size: 10

        config :web_push_encryption, :vapid_details, subject: "mailto:#{System.fetch_env!("NOTIFY_EMAIL")}"
        config :pleroma, :database, rum_enabled: false
        config :pleroma, :instance, static_dir: "/var/lib/pleroma/static"
        config :pleroma, Pleroma.Uploaders.Local, uploads: "/var/lib/pleroma/uploads"

        config :os_mon,
          start_cpu_sup: false,
          start_disksup: false,
          start_memsup: false
      ''
    ];
    services.pleroma.secretConfigFile = cfg.secretsFile;

    systemd.services.pleroma = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "${backend}-pleroma-db.service" ];
      requires = [ "${backend}-pleroma-db.service" ];
      environment = {
        DOMAIN = cfg.domain;
        PORT = toString cfg.port;
        INSTANCE_NAME = cfg.instanceName;
        ADMIN_EMAIL = cfg.adminEmail;
        NOTIFY_EMAIL = cfg.notifyEmail;
        ALLOW_REGISTRATION = if cfg.allowRegistration then "true" else "false";
      };
      serviceConfig.BindPaths =
        [ "${toString (pkgs.copyPathToStore cfg.faviconPath)}:/var/lib/pleroma/static/favicon.png" ];
    };

    nixfiles.oci-containers.containers.pleroma-db = {
      image = "postgres:${cfg.pgTag}";
      environment = {
        "POSTGRES_DB" = "pleroma";
        "POSTGRES_USER" = "pleroma";
        "POSTGRES_PASSWORD" = "pleroma";
      };
      extraOptions = [ "--shm-size=1g" ];
      volumes = [
        { name = "pgdata"; inner = "/var/lib/postgresql/data"; }
        { host = "/var/run/pleroma/db"; inner = "/var/run/postgresql"; }
      ];
      volumeSubDir = "pleroma";
    };

    # TODO: figure out how to get `sudo` in the unit's path (adding the package
    # doesn't help - need the wrapper)
    nixfiles.backups.scripts.pleroma = ''
      /run/wrappers/bin/sudo cp -a ${config.users.users.pleroma.home}/uploads uploads
      /run/wrappers/bin/sudo cp -a ${config.users.users.pleroma.home}/static/emoji/custom emoji
      /run/wrappers/bin/sudo chown -R ${config.nixfiles.backups.user}.${config.nixfiles.backups.group} uploads
      /run/wrappers/bin/sudo chown -R ${config.nixfiles.backups.user}.${config.nixfiles.backups.group} emoji
      ${backend} exec -i pleroma-db pg_dump -U pleroma --no-owner -Fc pleroma > postgres.dump
    '';
    security.sudo.extraRules = [
      {
        users = [ config.nixfiles.backups.user ];
        commands = [
          { command = "${pkgs.coreutils}/bin/cp -a ${config.users.users.pleroma.home}/uploads uploads"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.coreutils}/bin/cp -a ${config.users.users.pleroma.home}/static/emoji/custom emoji"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.coreutils}/bin/chown -R ${config.nixfiles.backups.user}.${config.nixfiles.backups.group} uploads"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.coreutils}/bin/chown -R ${config.nixfiles.backups.user}.${config.nixfiles.backups.group} emoji"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  };
}
