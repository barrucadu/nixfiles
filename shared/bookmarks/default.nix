{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.bookmarks;
  backend = config.nixfiles.oci-containers.backend;
in
{
  options.nixfiles.bookmarks = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    port = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "8.0.0"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    environmentFile = mkOption { type = types.nullOr types.str; default = null; };
    registry = {
      username = mkOption { type = types.nullOr types.str; default = null; };
      passwordFile = mkOption { type = types.nullOr types.str; default = null; };
      url = mkOption { type = types.nullOr types.str; default = null; };
    };
  };

  config = mkIf cfg.enable {
    nixfiles.oci-containers.containers.bookmarks = {
      image = cfg.image;
      login = with cfg.registry; { inherit username passwordFile; registry = url; };
      environment = {
        "ALLOW_WRITES" = if cfg.readOnly then "0" else "1";
        "BASE_URI" = cfg.baseURI;
        "ES_HOST" = "http://bookmarks-db:9200";
      };
      environmentFiles = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
      dependsOn = [ "bookmarks-db" ];
      network = "bookmarks_network";
      ports = [{ host = cfg.port; inner = 8888; }];
    };

    nixfiles.oci-containers.containers.bookmarks-db = {
      image = "elasticsearch:${cfg.esTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "xpack.security.enabled" = "false";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      network = "bookmarks_network";
      volumes = [{ name = "esdata"; inner = "/usr/share/elasticsearch/data"; }];
      volumeSubDir = "bookmarks";
    };

    nixfiles.backups.scripts.bookmarks = ''
      ${backend} exec -i bookmarks env ES_HOST=http://bookmarks-db:9200 python -m bookmarks.index.dump | gzip -9 > dump.json.gz
    '';
  };
}
