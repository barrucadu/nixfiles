{ config, lib, ... }:

with lib;

let
  cfg = config.nixfiles.eraseYourDarlings;
in
{
  options.nixfiles.eraseYourDarlings = {
    enable = mkOption { type = types.bool; default = false; };
    barrucaduPasswordFile = mkOption { type = types.str; };
    rootSnapshot = mkOption { type = types.str; default = "local/volatile/root@blank"; };
    persistDir = mkOption { type = types.path; default = "/persist"; };
    machineId = mkOption { type = types.str; };
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
    users.extraUsers.barrucadu.passwordFile = cfg.barrucaduPasswordFile;

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

    # Needs real path, not a symlink
    system.autoUpgrade.flake = mkForce "${cfg.persistDir}/etc/nixos";

    services.caddy.dataDir = "${toString cfg.persistDir}/var/lib/caddy";
    services.dockerRegistry.storagePath = "${toString cfg.persistDir}/var/lib/docker-registry";
    services.syncthing.dataDir = "${toString cfg.persistDir}/var/lib/syncthing";

    # my services
    nixfiles.bookdb.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/bookdb";
    nixfiles.bookmarks.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/bookmarks";
    nixfiles.concourse.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/concourse";
    nixfiles.finder.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/finder";
    nixfiles.foundryvtt.dataDir = "${toString cfg.persistDir}/srv/foundry";
    nixfiles.minecraft.dataDir = "${toString cfg.persistDir}/srv/minecraft";
    nixfiles.pleroma.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/pleroma";
    nixfiles.umami.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/umami";
    nixfiles.wikijs.dockerVolumeDir = "${toString cfg.persistDir}/docker-volumes/wikijs";
  };
}
