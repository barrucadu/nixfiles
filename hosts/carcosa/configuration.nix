{ config, lib, ... }:

with lib;
let
  dockerRegistryPort = 3000;
in
{
  ###############################################################################
  ## General
  ###############################################################################

  networking.hostName = "carcosa";
  networking.hostId = "f62895cc";
  boot.supportedFilesystems = [ "zfs" ];

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  # ZFS auto trim, scrub, & snapshot
  services.zfs.automation.enable = true;

  # Networking
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.trustedInterfaces = [ "lo" "docker0" ];

  networking.interfaces.enp1s0 = {
    ipv6.addresses = [{ address = "2a01:4f8:c0c:bfc1::"; prefixLength = 64; }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "enp1s0"; };


  ###############################################################################
  ## Make / volatile
  ###############################################################################

  boot.initrd.postDeviceCommands = mkAfter ''
    zfs rollback -r local/volatile/root@blank
  '';

  # Switch back to immutable users
  users.mutableUsers = mkForce false;
  users.extraUsers.barrucadu.initialPassword = mkForce null;
  users.extraUsers.barrucadu.hashedPassword = fileContents /etc/nixos/secrets/passwd-barrucadu.txt;

  # Store data in /persist (see also configuration elsewhere in this
  # file)
  services.openssh.hostKeys = [
    {
      path = "/persist/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
    {
      path = "/persist/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
  ];

  services.syncthing.dataDir = "/persist/var/lib/syncthing";

  systemd.tmpfiles.rules = [
    "L+ /etc/nixos - - - - /persist/etc/nixos"
  ];


  ###############################################################################
  ## Services
  ###############################################################################

  # WWW
  services.caddy.enable = true;
  services.caddy.config = ''
    registry.barrucadu.dev {
      encode gzip
      basicauth /v2/* {
        registry ${fileContents /etc/nixos/secrets/registry-password-hashed.txt}
      }
      header /v2/* Docker-Distribution-Api-Version "registry/2.0"
      reverse_proxy /v2/* http://127.0.0.1:${toString config.services.dockerRegistry.port}
    }
  '';

  # Docker registry
  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableDelete = true;
  services.dockerRegistry.enableGarbageCollect = true;
  services.dockerRegistry.garbageCollectDates = "daily";
  services.dockerRegistry.storagePath = "/persist/var/lib/docker-registry";
  services.dockerRegistry.port = dockerRegistryPort;
}
