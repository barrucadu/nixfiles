{ config, lib, ... }:

with lib;
let
  cfg = config.services.bookdb;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  options.services.bookdb = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "7.11.2"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.bookdb = {
      autoStart = true;
      image = cfg.image;
      environment = {
        "ALLOW_WRITES" = if cfg.readOnly then "0" else "1";
        "BASE_URI" = cfg.baseURI;
        "COVER_DIR" = "/bookdb-covers";
        "ES_HOST" = "http://bookdb-db:9200";
      };
      extraOptions = [ "--network=bookdb_network" ];
      dependsOn = [ "bookdb-db" ];
      ports = [ "127.0.0.1:${toString cfg.httpPort}:8888" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/covers:/bookdb-covers" ];
    };
    systemd.services."${backend}-bookdb" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.bookdb-db = {
      autoStart = true;
      image = "elasticsearch:${cfg.esTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      extraOptions = [ "--network=bookdb_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/esdata:/usr/share/elasticsearch/data" ];
    };
    systemd.services."${backend}-bookdb-db" = {
      preStart = "${backend} network create -d bridge bookdb_network || true";
      serviceConfig = serviceConfigForContainerLogging;
    };
  };
}
