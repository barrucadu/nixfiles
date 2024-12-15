# see remote-sync-send.nix
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.bookmarks.remoteSync.receive;
in
{
  config = mkIf cfg.enable {
    users.users.bookmarks-remote-sync-receive = {
      uid = 984;
      home = "/var/lib/bookmarks-remote-sync-receive";
      createHome = true;
      isSystemUser = true;
      openssh.authorizedKeys.keys = cfg.authorizedKeys;
      shell = pkgs.bashInteractive;
      group = "nogroup";
      packages =
        let
          receive-elasticsearch = ''
            env ES_HOST=${config.systemd.services.bookmarks.environment.ES_HOST} \
                ${pkgs.nixfiles.bookmarks}/bin/bookmarks_ctl import-index --drop-existing
          '';
        in
        [
          (pkgs.writeShellScriptBin "receive-elasticsearch" receive-elasticsearch)
        ];
    };
  };
}
