{ lib, ... }:

{
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "local/volatile/root";
      fsType = "zfs";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/6491-48C0";
      fsType = "vfat";
    };

  fileSystems."/home" =
    {
      device = "local/persistent/home";
      fsType = "zfs";
    };

  fileSystems."/mnt/nas" =
    {
      device = "data/nas";
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

  nix.maxJobs = lib.mkDefault 4;
}
