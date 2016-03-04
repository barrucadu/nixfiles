# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix

      # Include the standard configuration.
      ./base/default.nix

      # Include other configuration.
      #./services/nginx.nix
      #./services/openssh.nix
      #./services/xserver.nix
    ];

  # Use GRUB 2.
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Enable nvidia graphics
  #services.xserver.videoDrivers = [ "nvidia" ];
  #hardware.opengl.driSupport32Bit = true;

  # Holgate wifi issue
  #boot.kernelPackages = pkgs.linuxPackages_4_4;
  #nixpkgs.config.packageOverrides = pkgs: {
  #  linux_4_4 = pkgs.linux_4_4.override {
  #    kernelPatches = pkgs.linux_4_4.kernelPatches ++ [
  #      { patch = patches/wifi.patch; name = "wifi.patch"; }
  #    ];
  #  };
  #};

  # Enable pulseaudio
  #hardware.pulseaudio.enable = true;
  #hardware.pulseaudio.support32Bit = true;

  # Enable wifi
  networking.hostName = "myHostname";
  #networking.wireless.enable = true;
}
