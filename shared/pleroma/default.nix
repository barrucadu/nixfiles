# [Pleroma][] is a fediverese server.
#
# Pleroma uses a containerised postgres database.
#
# **Backups:** the postgres database, uploaded files, and custom emojis.
#
# **Erase your darlings:** transparently stores data on the persistent volume.
#
# [Pleroma]: https://pleroma.social/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.pleroma;
  backend = config.nixfiles.oci-containers.backend;
  backendPkg = if backend == "docker" then pkgs.docker else pkgs.podman;
in
{
  imports = [
    ./erase-your-darlings.nix
    ./options.nix
  ];

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
      wants = [ "network-online.target" ];
      requires = [ "${backend}-pleroma-db.service" ];
      environment = {
        DOMAIN = cfg.domain;
        PORT = toString cfg.port;
        INSTANCE_NAME = if cfg.instanceName == null then cfg.domain else cfg.instanceName;
        ADMIN_EMAIL = cfg.adminEmail;
        NOTIFY_EMAIL = if cfg.notifyEmail == null then cfg.adminEmail else cfg.notifyEmail;
        ALLOW_REGISTRATION = if cfg.allowRegistration then "true" else "false";
      };
      serviceConfig.BindPaths =
        [ "${toString (pkgs.copyPathToStore cfg.faviconPath)}:/var/lib/pleroma/static/favicon.png" ];
    };

    nixfiles.oci-containers.pods.pleroma.containers.db = {
      image = "postgres:${cfg.postgresTag}";
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
    };

    nixfiles.restic-backups.backups.pleroma = {
      prepareCommand = ''
        /run/wrappers/bin/sudo ${backendPkg}/bin/${backend} exec -i pleroma-db pg_dump -U pleroma --no-owner -Fc pleroma > postgres.dump
      '';
      paths = [
        config.users.users.pleroma.home
        "postgres.dump"
      ];
    };
    nixfiles.restic-backups.sudoRules = [
      { command = "${backendPkg}/bin/${backend} exec -i pleroma-db pg_dump -U pleroma --no-owner -Fc pleroma"; }
    ];
  };
}
