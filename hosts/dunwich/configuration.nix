{ pkgs, lib, ... }:

with lib;
{
  networking.hostName = "dunwich";

  system.autoUpgrade.allowReboot = mkForce false;

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  # Networking
  networking.interfaces.ens3 = {
    ipv6.addresses = [{ address = "2a01:4f8:c2c:2b22::"; prefixLength = 64; }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };

  # 10% of the RAM is too little space
  services.logind.extraConfig = ''
    RuntimeDirectorySize=2G
  '';

  # Extra packages
  environment.systemPackages = with pkgs; [
    haskellPackages.hledger
    irssi
    perl
  ];
}
