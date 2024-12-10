# see remote-sync-receive.nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.bookmarks.remoteSync.send;

  toService = target: {
    name = "bookmarks-sync-${target}";
    value = {
      description = "Upload bookmarks data to ${target}";
      startAt = "*:15";
      path = with pkgs; [ openssh ];
      serviceConfig = {
        ExecStart = pkgs.writeShellScript "bookmarks-sync" ''
          set -ex

          env "ES_HOST=$ES_HOST" \
              ${pkgs.nixfiles.bookmarks}/bin/bookmarks_ctl export-index | \
          ssh -i "$SSH_KEY_FILE" \
              -o UserKnownHostsFile=/dev/null \
              -o StrictHostKeyChecking=no \
              bookmarks-remote-sync-receive@${target} \
              receive-elasticsearch
        '';
        User = config.users.extraUsers.bookmarks-remote-sync-send.name;
      };
      environment = {
        ES_HOST = config.systemd.services.bookmarks.environment.ES_HOST;
        SSH_KEY_FILE = cfg.sshKeyFile;
      };
    };
  };
in
{
  config = mkIf cfg.enable {
    users.extraUsers.bookmarks-remote-sync-send = {
      home = "/var/lib/bookmarks-remote-sync-send";
      createHome = true;
      isSystemUser = true;
      shell = pkgs.bashInteractive;
      group = "nogroup";
    };

    systemd.services = listToAttrs (map toService cfg.targets);
  };
}
