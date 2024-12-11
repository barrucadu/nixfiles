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
  ###############################################################################
  ## General
  ###############################################################################

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

  ###############################################################################
  ## Website Mirror
  ###############################################################################

  nixfiles.hostTemplates.websiteMirror = {
    enable = true;
    acmeEnvironmentFile = config.sops.secrets."services/acme/env".path;
  };
  sops.secrets."services/acme/env" = { };

  ###############################################################################
  ## Remote Builds
  ###############################################################################

  nix.distributedBuilds = true;
  nix.buildMachines = [{
    hostName = "carcosa.barrucadu.co.uk";
    system = "x86_64-linux";
    sshUser = "nix-remote-builder";
    sshKey = config.sops.secrets."nix/build_machines/carcosa/ssh_key".path;
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUlTa0x0bk11bUs3N1RYUHBSa0VCeGI1NEtZVHZMZzhHUmFOeGl6c2NoMSsgcm9vdEBjYXJjb3NhCg==";
    protocol = "ssh-ng";
    maxJobs = 8;
  }];
  sops.secrets."nix/build_machines/carcosa/ssh_key" = { };
}
