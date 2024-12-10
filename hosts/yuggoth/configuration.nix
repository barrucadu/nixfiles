# This is a VPS (hosted by Hetzner Cloud).
#
# It serves a redundant deployment of a few of my websites.
#
# **Alerting:** disabled
#
# **Backups:** disabled
#
# **Public hostname:** `yuggoth.barrucadu.co.uk`
#
# **Role:** server
{ config, lib, pkgs, ... }:

with lib;
{
  networking.hostId = "62f520b4";
  boot.supportedFilesystems = { zfs = true; };

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking.interfaces.enp1s0 = {
    ipv6.addresses = [{ address = "2a01:4ff:f0:3a38::"; prefixLength = 64; }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "enp1s0"; };

  nixfiles.eraseYourDarlings.enable = true;
  nixfiles.eraseYourDarlings.machineId = "ee9cfe217f0f4d45bab5e897e782ca91";
  nixfiles.eraseYourDarlings.barrucaduPasswordFile = config.sops.secrets."users/barrucadu".path;
  sops.secrets."users/barrucadu".neededForUsers = true;
}

