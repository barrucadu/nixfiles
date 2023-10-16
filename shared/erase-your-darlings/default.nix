# Wipe `/` on boot, inspired by ["erase your darlings"][].
#
# This module is responsible for configuring standard NixOS options and
# services, all of my modules have their own `erase-your-darlings.nix` file
# which makes any changes that they need.
#
# This requires a setting up ZFS in a specific way when first installing NixOS.
# See the ["set up a new host"][] runbook.
#
# ["erase your darlings"]: https://grahamc.com/blog/erase-your-darlings/
# ["set up a new host"]: ./runbooks/set-up-a-new-host.md
{ config, lib, ... }:

with lib;

let
  cfg = config.nixfiles.eraseYourDarlings;
in
{
  imports = [
    ./options.nix
  ];

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
  };
}
