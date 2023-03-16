{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.bookmarks;
in
{
  options.nixfiles.bookmarks = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 48372; };
    esPort = mkOption { type = types.int; default = 43389; };
    esTag = mkOption { type = types.str; default = "8.0.0"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    environmentFile = mkOption { type = types.nullOr types.str; default = null; };
  };

  config = mkIf cfg.enable {
    systemd.services.bookmarks = {
      description = "barrucadu/bookmarks webapp";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.nixfiles.bookmarks}/bin/gunicorn -w 4 -t 60 -b 127.0.0.1:${toString cfg.port} bookmarks.serve:app";
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
        DynamicUser = "true";
        Restart = "always";
      };
      environment = {
        ALLOW_WRITES = if cfg.readOnly then "0" else "1";
        BASE_URI = cfg.baseURI;
        ES_HOST = "http://127.0.0.1:${toString cfg.esPort}";
      };
    };

    nixfiles.oci-containers.containers.bookmarks-db = {
      image = "elasticsearch:${cfg.esTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "xpack.security.enabled" = "false";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      ports = [{ host = cfg.esPort; inner = 9200; }];
      volumes = [{ name = "esdata"; inner = "/usr/share/elasticsearch/data"; }];
      volumeSubDir = "bookmarks";
    };

    nixfiles.backups.scripts.bookmarks = ''
      env ES_HOST=http://127.0.0.1:${toString cfg.esPort} ${pkgs.nixfiles.bookmarks}/bin/python -m bookmarks.index.dump | gzip -9 > dump.json.gz
    '';
  };
}
