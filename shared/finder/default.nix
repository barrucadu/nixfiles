{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.finder;
  backend = config.virtualisation.oci-containers.backend;
in
{
  options.nixfiles.finder = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    port = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "8.0.0"; };
    dockerVolumeDir = mkOption { type = types.path; };
    mangaDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.finder = {
      autoStart = true;
      image = cfg.image;
      environment = {
        "DATA_DIR" = "/data";
        "ES_HOST" = "http://finder-db:9200";
      };
      extraOptions = [ "--network=finder_network" ];
      dependsOn = [ "finder-db" ];
      ports = [ "127.0.0.1:${toString cfg.port}:8888" ];
      volumes = [ "${toString cfg.mangaDir}:/data" ];
    };

    virtualisation.oci-containers.containers.finder-db = {
      autoStart = true;
      image = "elasticsearch:${cfg.esTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "xpack.security.enabled" = "false";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      extraOptions = [ "--network=finder_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/esdata:/usr/share/elasticsearch/data" ];
    };
    systemd.services."${backend}-finder-db".preStart = "${backend} network create -d bridge finder_network || true";
  };
}