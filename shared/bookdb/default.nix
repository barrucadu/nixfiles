# [bookdb][] is a webapp to keep track of all my books, with a public instance
# on [bookdb.barrucadu.co.uk][].
#
# bookdb uses a containerised elasticsearch database, it also stores uploaded
# book cover images.
#
# **Backups:** the elasticsearch database and uploaded files.
#
# **Erase your darlings:** overrides the `dataDir`.
#
# [bookdb]: https://github.com/barrucadu/bookdb
# [bookdb.barrucadu.co.uk]: https://bookdb.barrucadu.co.uk/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.bookdb;
  backend = config.nixfiles.oci-containers.backend;
in
{
  imports = [
    ./erase-your-darlings.nix
    ./options.nix
  ];

  config = mkIf cfg.enable {
    systemd.services.bookdb = {
      description = "barrucadu/bookdb webapp";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "${backend}-bookdb-db.service" ];
      requires = [ "${backend}-bookdb-db.service" ];
      path = [ pkgs.imagemagick ];
      serviceConfig = {
        ExecStart = "${pkgs.nixfiles.bookdb}/bin/gunicorn -w 4 -t 60 -b 127.0.0.1:${toString cfg.port} bookdb.serve:app";
        Restart = "always";
        User = config.users.users.bookdb.name;
      };
      environment = {
        "ALLOW_WRITES" = if cfg.readOnly then "0" else "1";
        "BASE_URI" = cfg.baseURI;
        "COVER_DIR" = "${cfg.dataDir}/covers";
        "ES_HOST" = "http://127.0.0.1:${toString cfg.elasticsearchPort}";
        "UUIDS_FILE" = ./uuids.yaml;
      };
    };

    nixfiles.oci-containers.pods.bookdb.containers.db = {
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

    users.users.bookdb = {
      description = "bookdb service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "nogroup";
    };

    nixfiles.restic-backups.backups.bookdb = {
      prepareCommand = ''
        env ES_HOST=${config.systemd.services.bookdb.environment.ES_HOST} ${pkgs.nixfiles.bookdb}/bin/python -m bookdb.index.dump > elasticsearch-dump.json
      '';
      paths = [
        cfg.dataDir
        "elasticsearch-dump.json"
      ];
    };
  };
}
