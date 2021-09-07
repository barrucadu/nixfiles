{ config, lib, ... }:

with lib;
let
  cfg = config.services.etherpad;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  options.services.etherpad = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    pgTag = mkOption { type = types.str; default = "13"; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.etherpad = {
      autoStart = true;
      image = cfg.image;
      environment = {
        "DB_TYPE" = "postgres";
        "DB_HOST" = "etherpad-db";
        "DB_PORT" = "5432";
        "DB_NAME" = "etherpad";
        "DB_USER" = "etherpad";
        "DB_PASS" = "etherpad";
        "TRUST_PROXY" = "true";
      };
      extraOptions = [ "--network=etherpad_network" ];
      dependsOn = [ "etherpad-db" ];
      ports = [ "127.0.0.1:${toString cfg.httpPort}:9001" ];
    };
    systemd.services."${backend}-etherpad" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.etherpad-db = {
      autoStart = true;
      image = "postgres:${cfg.pgTag}";
      environment = {
        "POSTGRES_DB" = "etherpad";
        "POSTGRES_USER" = "etherpad";
        "POSTGRES_PASSWORD" = "etherpad";
      };
      extraOptions = [ "--network=etherpad_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/pgdata:/var/lib/postgresql/data" ];
    };
    systemd.services."${backend}-etherpad-db" = {
      preStart = "${backend} network create -d bridge etherpad_network || true";
      serviceConfig = serviceConfigForContainerLogging;
    };
  };
}
