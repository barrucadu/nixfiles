{ pkgs, ... }:

{
  # http://lists.science.uu.nl/pipermail/nix-dev/2016-May/020343.html
  nixpkgs.config.packageOverrides = super: rec {
    linux_4_4 = super.linux_4_4.override {
      kernelPatches = [
        { patch = ../patches/wifi.patch; name = "Holgate wifi issue"; }
      ];
    };
    linuxPackages_4_4 = super.recurseIntoAttrs
      (super.linuxPackagesFor linux_4_4 linuxPackages_4_4);
    linuxPackages = linuxPackages_4_4;
    linux = linuxPackages.kernel;
  };
}
