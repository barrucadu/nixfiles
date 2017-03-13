{ ... }:

{
  networking.hostName = "yig";

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # Include the standard configuration.
      ./base/default.nix

      # Include other configuration.
      ./services/openssh.nix
      ./services/syncthing.nix
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

  # Enable redshift
  services.redshift = {
    enable = true;
    # York
    latitude  = "53.953";
    longitude = "-1.0391";
  };

  # Enable touchpad
  services.xserver.synaptics.enable = true;
}
