{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.finder;
in
{
  options.nixfiles.finder = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    port = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "8.0.0"; };
    mangaDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    nixfiles.oci-containers.pods.finder = {
      containers = {
        web = {
          image = cfg.image;
          environment = {
            "DATA_DIR" = "/data";
            "ES_HOST" = if config.nixfiles.oci-containers.backend == "docker" then "http://finder-db:9200" else "http://localhost:9200";
          };
          dependsOn = [ "finder-db" ];
          ports = [{ host = cfg.port; inner = 8888; }];
          volumes = [{ host = cfg.mangaDir; inner = "/data"; }];
        };

        db = {
          image = "elasticsearch:${cfg.esTag}";
          environment = {
            "http.host" = "0.0.0.0";
            "discovery.type" = "single-node";
            "xpack.security.enabled" = "false";
            "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
          };
          volumes = [{ name = "esdata"; inner = "/usr/share/elasticsearch/data"; }];
        };
      };
    };
  };
}
