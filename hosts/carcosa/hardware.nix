{ ... }:

{
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "local/volatile/root";
      fsType = "zfs";
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

  fileSystems."/var/concourse-worker-scratch" =
    {
      device = "/dev/disk/by-uuid/bbc94c9d-9e32-435b-9fe7-1290acb96a40";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/C83B-AA71";
      fsType = "vfat";
    };

  swapDevices = [ ];

}
