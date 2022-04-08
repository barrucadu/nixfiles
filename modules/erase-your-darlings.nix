{ config, lib, ... }:

with lib;

let
  cfg = config.modules.eraseYourDarlings;
in
{
  options = {
    modules = {
      eraseYourDarlings = {
        enable = mkOption { type = types.bool; default = false; };
        barrucaduHashedPassword = mkOption { type = types.str; };
        rootSnapshot = mkOption { type = types.str; default = "local/volatile/root@blank"; };
        persistDir = mkOption { type = types.path; default = "/persist"; };
        machineId = mkOption { type = types.str; };
      };
    };
  };

  config = mkIf cfg.enable {
    # Wipe / on boot
    boot.initrd.postDeviceCommands = mkAfter ''
      zfs rollback -r ${cfg.rootSnapshot}
    '';

    # Set /etc/machine-id, so that journalctl can access logs from
    # previous boots.
    environment.etc.machine-id = {
      text = "${cfg.machineId}\n";
      mode = "0444";
    };

    # Switch back to immutable users
    users.mutableUsers = mkForce false;
    users.extraUsers.barrucadu.initialPassword = mkForce null;
    users.extraUsers.barrucadu.hashedPassword = cfg.barrucaduHashedPassword;

    # Persist state in `cfg.persistDir`
    services.openssh.hostKeys = [
      {
        path = "${toString cfg.persistDir}/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "${toString cfg.persistDir}/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];

    services.samba.extraConfig = ''
      log file = /var/log/samba/%m.log
      private dir = ${toString cfg.persistDir}/var/lib/samba/private
    '';

    systemd.tmpfiles.rules = [
      "L+ /etc/nixos - - - - ${toString cfg.persistDir}/etc/nixos"
    ];

    systemd.services.prometheus.serviceConfig.BindPaths = "${toString cfg.persistDir}/var/lib/${config.services.prometheus.stateDir}:/var/lib/${config.services.prometheus.stateDir}";

    services.caddy.dataDir = "${toString cfg.persistDir}/var/lib/caddy";
    services.dockerRegistry.storagePath = "${toString cfg.persistDir}/var/lib/docker-registry";
    services.grafana.dataDir = "${toString cfg.persistDir}/var/lib/grafana";
    services.syncthing.dataDir = "${toString cfg.persistDir}/var/lib/syncthing";

    # my services
    services.bookdb.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/bookdb";
    services.bookmarks.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/bookmarks";
    services.commento.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/commento";
    services.concourse.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/concourse";
    services.finder.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/finder";
    services.gitea.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/gitea";
    services.minecraft.dataDir = "${toString cfg.persistDir}/srv/minecraft";
    services.pleroma.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/pleroma";
    services.umami.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/umami";
  };
}
