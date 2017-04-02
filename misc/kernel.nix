{ ... }:

{
  boot.kernelPatches = [
    { patch = ../patches/wifi.patch; name = "Holgate wifi issue"; }
  ];
}
