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

          /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/cp -r ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR}/ ~/bookdb-covers
          trap "/run/wrappers/bin/sudo ${pkgs.coreutils}/bin/rm -rf ~/bookdb-covers" EXIT
          rsync -az\
                -e "ssh -i $SSH_KEY_FILE -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" \
                ~/bookdb-covers/ \
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
        User = config.users.extraUsers.bookdb-remote-sync-send.name;
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
    users.extraUsers.bookdb-remote-sync-send = {
      home = "/var/lib/bookdb-remote-sync-send";
      createHome = true;
      isSystemUser = true;
      shell = pkgs.bashInteractive;
      group = "nogroup";
    };

    systemd.services = listToAttrs (map toService cfg.targets);

    security.sudo.extraRules = [
      {
        users = [ config.users.extraUsers.bookdb-remote-sync-send.name ];
        commands = [
          { command = "${pkgs.coreutils}/bin/cp -r ${config.systemd.services.bookdb.environment.BOOKDB_UPLOADS_DIR}/ ${config.users.extraUsers.bookdb-remote-sync-send.home}/bookdb-covers"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.coreutils}/bin/rm -rf ${config.users.extraUsers.bookdb-remote-sync-send.home}/bookdb-covers"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  };
}
