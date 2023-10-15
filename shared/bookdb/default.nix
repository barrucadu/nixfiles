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
        "ES_HOST" = "http://127.0.0.1:${toString cfg.esPort}";
        "UUIDS_FILE" = ./uuids.yaml;
      };
    };

    nixfiles.oci-containers.containers.bookdb-db = {
      image = "elasticsearch:${cfg.esTag}";
      environment = {
        "http.host" = "0.0.0.0";
        "discovery.type" = "single-node";
        "xpack.security.enabled" = "false";
        "ES_JAVA_OPTS" = "-Xms512M -Xmx512M";
      };
      ports = [{ host = cfg.esPort; inner = 9200; }];
      volumes = [{ name = "esdata"; inner = "/usr/share/elasticsearch/data"; }];
      volumeSubDir = "bookdb";
    };

    users.users.bookdb = {
      description = "bookdb service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "nogroup";
    };

    # TODO: figure out how to get `sudo` in the unit's path (adding the
    # package doesn't help - need the wrapper)
    nixfiles.backups.scripts.bookdb = ''
      /run/wrappers/bin/sudo cp -a ${cfg.dataDir}/covers covers
      env ES_HOST=${config.systemd.services.bookdb.environment.ES_HOST} ${pkgs.nixfiles.bookdb}/bin/python -m bookdb.index.dump | gzip -9 > dump.json.gz
    '';
    nixfiles.backups.sudoRules = [
      { command = "${pkgs.coreutils}/bin/cp -a ${cfg.dataDir}/covers covers"; }
    ];
  };
}
