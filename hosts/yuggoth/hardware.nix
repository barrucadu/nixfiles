{ ... }:

{
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "local/volatile/root";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/A5EB-2AC0";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/home" =
    {
      device = "local/persistent/home";
      fsType = "zfs";
    };

  fileSystems."/nix" =
    {
      device = "local/persistent/nix";
      fsType = "zfs";
    };

  fileSystems."/persist" =
    {
      device = "local/persistent/persist";
      fsType = "zfs";
      neededForBoot = true;
    };

  fileSystems."/var/log" =
    {
      device = "local/persistent/var-log";
      fsType = "zfs";
    };

  swapDevices = [ ];
}
