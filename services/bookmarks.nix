{ config, lib, ... }:

with lib;
let
  cfg = config.services.bookmarks;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  options.services.bookmarks = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    httpPort = mkOption { type = types.int; default = 3000; };
    esTag = mkOption { type = types.str; default = "8.0.0"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    youtubeApiKey = mkOption { type = types.nullOr types.str; default = null; };
    environmentFile = mkOption { type = types.nullOr types.str; default = null; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.bookmarks = {
      autoStart = true;
      image = cfg.image;
      environment = {
        "ALLOW_WRITES" = if cfg.readOnly then "0" else "1";
        "BASE_URI" = cfg.baseURI;
        "ES_HOST" = "http://bookmarks-db:9200";
        "YOUTUBE_API_KEY" = mkIf (cfg.youtubeApiKey != null) cfg.youtubeApiKey;
      };
      environmentFiles = mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
      extraOptions = [ "--network=bookmarks_network" ];
      dependsOn = [ "bookmarks-db" ];
      ports = [ "127.0.0.1:${toString cfg.httpPort}:8888" ];
    };
    systemd.services."${backend}-bookmarks" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.bookmarks-db = {
      autoStart = true;
      image = "elasticsearch:${cfg.esTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "xpack.security.enabled" = "false";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      extraOptions = [ "--network=bookmarks_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/esdata:/usr/share/elasticsearch/data" ];
    };
    systemd.services."${backend}-bookmarks-db" = {
      preStart = "${backend} network create -d bridge bookmarks_network || true";
      serviceConfig = serviceConfigForContainerLogging;
    };
  };
}
