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
        ExecStart = "${pkgs.nixfiles.bookmarks}/bin/bookmarks ${optionalString (!cfg.readOnly) "--allow-writes"}";
        DynamicUser = "true";
        Restart = "always";
      };
      environment = {
        BOOKMARKS_ADDRESS = "127.0.0.1:${toString cfg.port}";
        ES_HOST = "http://127.0.0.1:${toString cfg.elasticsearchPort}";
        RUST_LOG = cfg.logLevel;
        RUST_LOG_FORMAT = cfg.logFormat;
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
        env ES_HOST=${config.systemd.services.bookmarks.environment.ES_HOST} ${pkgs.nixfiles.bookmarks}/bin/bookmarks_ctl export-index > elasticsearch-dump.json
      '';
      paths = [
        "elasticsearch-dump.json"
      ];
    };
  };
}
