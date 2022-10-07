{ config, lib, ... }:

with lib;
let
  cfg = config.services.bookdb;
  backend = config.virtualisation.oci-containers.backend;
in
{
  options.services.bookdb = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    port = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "8.0.0"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    registry = {
      username = mkOption { type = types.nullOr types.str; default = null; };
      passwordFile = mkOption { type = types.nullOr types.str; default = null; };
      url = mkOption { type = types.nullOr types.str; default = null; };
    };
    pullOnStart = mkOption { type = types.bool; default = false; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.bookdb = {
      autoStart = true;
      image = cfg.image;
      login = with cfg.registry; { inherit username passwordFile; registry = url; };
      environment = {
        "ALLOW_WRITES" = if cfg.readOnly then "0" else "1";
        "BASE_URI" = cfg.baseURI;
        "COVER_DIR" = "/bookdb-covers";
        "ES_HOST" = "http://bookdb-db:9200";
      };
      extraOptions = [ "--network=bookdb_network" ];
      dependsOn = [ "bookdb-db" ];
      ports = [ "127.0.0.1:${toString cfg.port}:8888" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/covers:/bookdb-covers" ];
    };
    systemd.services."${backend}-bookdb".preStart = mkIf cfg.pullOnStart "${backend} pull ${cfg.image}";

    virtualisation.oci-containers.containers.bookdb-db = {
      autoStart = true;
      image = "elasticsearch:${cfg.esTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "xpack.security.enabled" = "false";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      extraOptions = [ "--network=bookdb_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/esdata:/usr/share/elasticsearch/data" ];
    };
    systemd.services."${backend}-bookdb-db".preStart = "${backend} network create -d bridge bookdb_network || true";

    nixfiles.backups.scripts.bookdb = ''
      ${backend} cp "bookdb:/bookdb-covers" covers
      ${backend} exec -i bookdb env ES_HOST=http://bookdb-db:9200 /app/dump-index.py | gzip -9 > dump.json.gz
    '';
  };
}
