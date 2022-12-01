{ ... }:

{
  boot.initrd.availableKernelModules = [ "ehci_pci" "ahci" "xhci_pci" "sd_mod" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/df4fd0b5-bbfb-4053-9c77-ff05be9d0862";
      fsType = "ext4";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/54907586-5213-4156-aebf-6b891a94abb6"; }];

  powerManagement.cpuFreqGovernor = "powersave";
}
