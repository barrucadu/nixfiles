# [donetick][] is a "task & chore" management tool.
#
# donetick runs as a dockerised service.
#
# The `environmentFile` must contain the following env vars:
#
#   - `DT_JWT_SECRET`
#
# **Backups:** the data directory.
#
# **Erase your darlings:** transparently stores data on the persistent volume.
#
# [donetick]: https://donetick.com/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.donetick;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    nixfiles.oci-containers.pods.donetick.containers.web = {
      image = "mirror.gcr.io/donetick/donetick:${cfg.tag}";
      environment = {
        "DT_NAME" = "selfhosted";
        "DT_IS_DONE_TICK_DOT_COM" = "false";
        "DT_DATABASE_TYPE" = "sqlite";
        "DT_DATABASE_MIGRATION" = "true";
        "DT_SQLITE_PATH" = "/donetick-data/donetick.db";
        "DT_JWT_SESSION_TIME" = "168h";
        "DT_JWT_MAX_REFRESH" = "168h";
        "DT_SERVER_PORT" = "2021";
        "DT_SERVER_CORS_ALLOW_ORIGINS" = "http://${cfg.domain},https://${cfg.domain}";
        "DT_SERVER_SERVE_FRONTEND" = "true";
        "DT_LOGGING_LEVEL" = "info";
        "DT_LOGGING_ENCODING" = "json";
        "DT_REALTIME_enabled" = "true";
        "DT_REALTIME_SSE_ENABLED" = "true";
        "DT_REALTIME_WEBSOCKET_ENABLED" = "false";
      };
      environmentFiles = [ cfg.environmentFile ];
      ports = [{ host = cfg.port; inner = 2021; }];
      volumes = [
        { name = "data"; inner = "/donetick-data"; }
      ];
    };

    nixfiles.restic-backups.backups.donetick = {
      prepareCommand = ''
        /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl stop podman-donetick-web
      '';
      cleanupCommand = ''
        /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl start podman-donetick-web
      '';
      paths = [
        "${config.nixfiles.oci-containers.volumeBaseDir}/donetick/data"
      ];
    };
    nixfiles.restic-backups.sudoRules = [
      { command = "${pkgs.systemd}/bin/systemctl stop podman-donetick-web"; }
      { command = "${pkgs.systemd}/bin/systemctl start podman-donetick-web"; }
    ];
  };
}
