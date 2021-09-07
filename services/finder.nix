{ config, lib, ... }:

with lib;
let
  cfg = config.services.finder;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  options.services.finder = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "7.11.2"; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
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
      ports = [ "127.0.0.1:${toString cfg.httpPort}:8888" ];
      volumes = [ "${toString cfg.mangaDir}:/data" ];
    };
    systemd.services."${backend}-finder" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.finder-db = {
      autoStart = true;
      image = "elasticsearch:${cfg.esTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      extraOptions = [ "--network=finder_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/esdata:/usr/share/elasticsearch/data" ];
    };
    systemd.services."${backend}-finder-db" = {
      preStart = "${backend} network create -d bridge finder_network || true";
      serviceConfig = serviceConfigForContainerLogging;
    };
  };
}
