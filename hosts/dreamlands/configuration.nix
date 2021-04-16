{ lib, ... }:

with lib;
let
  giteaHttpPort = 3000;
in
{
  networking.hostName = "dreamlands";

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  # Networking
  networking.firewall.allowedTCPPorts = [ 80 222 443 ];

  networking.interfaces.ens3 = {
    ipv6.addresses = [{ address = "2a01:4f8:c0c:77b3::"; prefixLength = 64; }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };

  # WWW
  services.caddy.enable = true;
  services.caddy.config = ''
    git.barrucadu.dev {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString giteaHttpPort}
    }
  '';

  services.gitea.enable = true;
  services.gitea.httpPort = giteaHttpPort;
  services.gitea.dockerVolumeDir = /persist/docker-volumes/gitea;
}
