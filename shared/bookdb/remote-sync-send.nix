# See remote-sync-receive.nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.bookdb.remoteSync.send;

  toService = target: {
    name = "bookdb-sync-${target}";
    value = {
      description = "Upload bookdb data to ${target}";
      startAt = "*:15";
      path = with pkgs; [ openssh rsync ];
      serviceConfig = {
        ExecStart = pkgs.writeShellScript "bookdb-sync" ''
          set -ex

          cd $RUNTIME_DIRECTORY

          /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cp --preserve=timestamps -r ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR}/ bookdb-covers
          trap "/run/wrappers/bin/sudo ${pkgs.coreutils}/bin/rm -rf bookdb-covers" EXIT
          rsync -az\
                -e "ssh -i $SSH_KEY_FILE -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
                bookdb-covers/ \
                bookdb-remote-sync-receive@${target}:~/bookdb-covers/
          ssh -i "$SSH_KEY_FILE" \
              -o UserKnownHostsFile=/dev/null \
              -o StrictHostKeyChecking=no \
              bookdb-remote-sync-receive@${target} \
              receive-covers

          env "ES_HOST=$ES_HOST" \
              ${pkgs.nixfiles.bookdb}/bin/bookdb_ctl export-index | \
          ssh -i "$SSH_KEY_FILE" \
              -o UserKnownHostsFile=/dev/null \
              -o StrictHostKeyChecking=no \
              bookdb-remote-sync-receive@${target} \
              receive-elasticsearch
        '';
        User = config.users.users.bookdb-remote-sync-send.name;
        RuntimeDirectory = "bookdb-sync-${target}";
      };
      environment = {
        ES_HOST = config.systemd.services.bookdb.environment.ES_HOST;
        SSH_KEY_FILE = cfg.sshKeyFile;
      };
    };
  };
in
{
  config = mkIf cfg.enable {
    users.users.bookdb-remote-sync-send = {
      uid = 985;
      isSystemUser = true;
      shell = pkgs.bashInteractive;
      group = "nogroup";
    };

    systemd.services = listToAttrs (map toService cfg.targets);

    security.sudo.extraRules = [
      {
        users = [ config.users.users.bookdb-remote-sync-send.name ];
        commands = [
          { command = "${pkgs.coreutils}/bin/cp --preserve=timestamps -r ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR}/ bookdb-covers"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.coreutils}/bin/rm -rf bookdb-covers"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  };
}
