{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.finder;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    nixfiles.oci-containers.pods.finder = {
      containers = {
        web = {
          image = cfg.image;
          environment = {
            "DATA_DIR" = "/data";
            "ES_HOST" = "http://finder-db:9200";
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
