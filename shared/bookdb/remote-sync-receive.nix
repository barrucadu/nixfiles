# See remote-sync-send.nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.bookdb.remoteSync.receive;
in
{
  config = mkIf cfg.enable {
    users.users.bookdb-remote-sync-receive = {
      uid = 985;
      home = "/var/lib/bookdb-remote-sync-receive";
      createHome = true;
      isSystemUser = true;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
      shell = pkgs.bashInteractive;
      group = "nogroup";
      packages =
        let
          receive-covers = ''
            if [[ ! -d ~/bookdb-covers ]]; then
              echo "bookdb-covers does not exist"
              exit 1
            fi

            /run/wrappers/bin/sudo ${pkgs.rsync}/bin/rsync -a --delete ~/bookdb-covers/ ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR} || exit 1
            /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/chown -R ${config.users.users.bookdb.name}.nogroup ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR} || exit 1
          '';
          receive-elasticsearch = ''
            env ES_HOST=${config.systemd.services.bookdb.environment.ES_HOST} \
                ${pkgs.nixfiles.bookdb}/bin/bookdb_ctl import-index --drop-existing
          '';
        in
        [
          (pkgs.writeShellScriptBin "receive-covers" receive-covers)
          (pkgs.writeShellScriptBin "receive-elasticsearch" receive-elasticsearch)
        ];
    };

    security.sudo.extraRules = [
      {
        users = [ config.users.users.bookdb-remote-sync-receive.name ];
        commands = [
          { command = "${pkgs.rsync}/bin/rsync -a --delete ${config.users.users.bookdb-remote-sync-receive.home}/bookdb-covers/ ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR}"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.coreutils}/bin/chown -R ${config.users.users.bookdb.name}.nogroup ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR}"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  };
}
