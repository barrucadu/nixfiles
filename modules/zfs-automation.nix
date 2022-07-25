{ config, lib, ... }:

with lib;

let
  cfg = config.modules.zfsAutomation;
in
{
  options = {
    modules = {
      zfsAutomation = {
        enable = mkOption { type = types.bool; default = false; };
      };
    };
  };

  config = mkIf cfg.enable {
    # Auto-trim is enabled per-pool:
    # run `sudo zpool set autotrim=on <pool>`
    services.zfs.trim.enable = true;
    services.zfs.trim.interval = "weekly";

    # Auto-scrub applies to all pools, no need to set any pool
    # properties.
    services.zfs.autoScrub.enable = true;
    services.zfs.autoScrub.interval = "monthly";

    # Auto-snapshot is enabled per dataset:
    # run `sudo zfs set com.sun:auto-snapshot=true <dataset>`
    #
    # The default of 12 monthly snapshots takes up too much disk space
    # in practice.
    services.zfs.autoSnapshot.enable = true;
    services.zfs.autoSnapshot.monthly = 3;

    services.monitoring.scripts.zfs = ''
      if [[ "$(zpool status -x)" != "all pools are healthy" ]]; then
        zpool status
        exit 1
      fi
    '';
  };
}
