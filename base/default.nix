{ config, ... }:

{
  # The NixOS release to be compatible with for stateful data such as databases.
  system.stateVersion = "16.03pre";

  # Use GRUB 2, defaulting to /dev/sda1.
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Pull in the rest of the default configuration
  imports = [
    ./locale.nix
    ./packages.nix
    ./users.nix
  ];
}
