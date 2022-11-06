{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.bookdb;
  backend = config.nixfiles.oci-containers.backend;
in
{
  options.nixfiles.bookdb = {
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
  };

  config = mkIf cfg.enable {
    nixfiles.oci-containers.containers.bookdb = {
      image = cfg.image;
      login = with cfg.registry; { inherit username passwordFile; registry = url; };
      environment = {
        "ALLOW_WRITES" = if cfg.readOnly then "0" else "1";
        "BASE_URI" = cfg.baseURI;
        "COVER_DIR" = "/bookdb-covers";
        "ES_HOST" = "http://bookdb-db:9200";
      };
      dependsOn = [ "bookdb-db" ];
      network = "bookdb_network";
      ports = [{ host = cfg.port; inner = 8888; }];
      volumes = [{ name = "covers"; inner = "/bookdb-covers"; }];
    };

    nixfiles.oci-containers.containers.bookdb-db = {
      image = "elasticsearch:${cfg.esTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "xpack.security.enabled" = "false";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      network = "bookdb_network";
      volumes = [{ name = "esdata"; inner = "/usr/share/elasticsearch/data"; }];
      volumeSubDir = "bookdb";
    };

    nixfiles.backups.scripts.bookdb = ''
      ${backend} cp "bookdb:/bookdb-covers" covers
      ${backend} exec -i bookdb env ES_HOST=http://bookdb-db:9200 /app/dump-index.py | gzip -9 > dump.json.gz
    '';
  };
}
