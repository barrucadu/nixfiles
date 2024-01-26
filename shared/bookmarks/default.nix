# [bookmarks][] is a webapp to keep track of all my bookmarks, with a public
# instance on [bookmarks.barrucadu.co.uk][].
#
# bookmarks uses a containerised elasticsearch database.
#
# **Backups:** the elasticsearch database.
#
# [bookmarks]: https://github.com/barrucadu/bookmarks
# [bookmarks.barrucadu.co.uk]: https://bookmarks.barrucadu.co.uk/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.bookmarks;
  backend = config.nixfiles.oci-containers.backend;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    systemd.services.bookmarks = {
      description = "barrucadu/bookmarks webapp";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "${backend}-bookmarks-db.service" ];
      requires = [ "${backend}-bookmarks-db.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.nixfiles.bookmarks}/bin/gunicorn -w 4 -t 60 -b 127.0.0.1:${toString cfg.port} bookmarks.serve:app";
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
        DynamicUser = "true";
        Restart = "always";
      };
      environment = {
        ALLOW_WRITES = if cfg.readOnly then "0" else "1";
        BASE_URI = cfg.baseURI;
        ES_HOST = "http://127.0.0.1:${toString cfg.elasticsearchPort}";
      };
    };

    nixfiles.oci-containers.pods.bookmarks.containers.db = {
      image = "elasticsearch:${cfg.elasticsearchTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "xpack.security.enabled" = "false";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      ports = [{ host = cfg.elasticsearchPort; inner = 9200; }];
      volumes = [{ name = "esdata"; inner = "/usr/share/elasticsearch/data"; }];
    };

    nixfiles.restic-backups.backups.bookmarks = {
      prepareCommand = ''
        env ES_HOST=http://127.0.0.1:${toString cfg.elasticsearchPort} ${pkgs.nixfiles.bookmarks}/bin/python -m bookmarks.index.dump > elasticsearch-dump.json
      '';
      paths = [
        "elasticsearch-dump.json"
      ];
    };

    nixfiles.backups.scripts.bookmarks = ''
      env ES_HOST=http://127.0.0.1:${toString cfg.elasticsearchPort} ${pkgs.nixfiles.bookmarks}/bin/python -m bookmarks.index.dump | gzip -9 > dump.json.gz
    '';
  };
}
