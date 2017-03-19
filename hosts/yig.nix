{ ... }:

{
  networking.hostName = "yig";

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # Include the standard configuration.
      ./common.nix

      # Include other configuration.
      ./services/xserver.nix
    ];

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Enable pulseaudio
  hardware.pulseaudio.enable = true;
  hardware.pulseaudio.support32Bit = true;

  # Enable wifi
  networking.wireless.enable = true;

  # Enable touchpad
  services.xserver.synaptics.enable = true;
}
