{ config, pkgs, lib, ... }:

with lib;
let
  pullDevDockerImage = pkgs.writeShellScript "pull-dev-docker-image.sh" ''
    set -e
    set -o pipefail

    ${pkgs.coreutils}/bin/cat /etc/nixos/secrets/registry-password.txt | ${pkgs.docker}/bin/docker login --username registry --password-stdin https://registry.barrucadu.dev
    ${pkgs.docker}/bin/docker pull registry.barrucadu.dev/$1
  '';

in
{
  networking.hostName = "dunwich";

  system.autoUpgrade.allowReboot = mkForce false;

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  # Networking
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  networking.interfaces.ens3 = {
    ipv6.addresses = [{ address = "2a01:4f8:c2c:2b22::"; prefixLength = 64; }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };

  # Web server
  services.caddy.enable = true;
  services.caddy.config = ''
    ${config.services.pleroma.domain} {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.pleroma.httpPort}
    }

    pad.barrucadu.co.uk {
      basicauth {
        ${fileContents /etc/nixos/secrets/etherpad-basic-auth-credentials.txt}
      }

      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.etherpad.httpPort}
    }
  '';

  # Pleroma
  services.pleroma.enable = true;
  services.pleroma.image = "registry.barrucadu.dev/pleroma:latest";
  services.pleroma.domain = "ap.barrucadu.co.uk";
  services.pleroma.secretKeyBase = fileContents /etc/nixos/secrets/pleroma/secret-key-base.txt;
  services.pleroma.signingSalt = fileContents /etc/nixos/secrets/pleroma/signing-salt.txt;
  services.pleroma.webPushPublicKey = fileContents /etc/nixos/secrets/pleroma/web-push-public-key.txt;
  services.pleroma.webPushPrivateKey = fileContents /etc/nixos/secrets/pleroma/web-push-private-key.txt;
  services.pleroma.execStartPre = "${pullDevDockerImage} pleroma:latest";
  services.pleroma.dockerVolumeDir = /persist/docker-volumes/pleroma;

  # etherpad
  services.etherpad.enable = true;
  services.etherpad.image = "etherpad/etherpad:stable";
  services.etherpad.httpPort = 3006;
  services.etherpad.dockerVolumeDir = /persist/docker-volumes/etherpad;

  # minecraft
  services.minecraft.enable = true;

  # barrucadu.dev concourse access
  security.sudo.extraRules = [
    {
      users = [ "concourse-deploy-robot" ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl restart pleroma"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];
  users.extraUsers.concourse-deploy-robot = {
    home = "/home/system/concourse-deploy-robot";
    createHome = true;
    isSystemUser = true;
    openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/YTj08251qhEjYcQHMRHcwlOJPGrt8dM/YqYi9J5kM concourse-worker@cd.barrucadu.dev" ];
    shell = pkgs.bashInteractive;
  };

  # 10% of the RAM is too little space
  services.logind.extraConfig = ''
    RuntimeDirectorySize=2G
  '';

  # Extra packages
  environment.systemPackages = with pkgs; [
    haskellPackages.hledger
    irssi
    perl
  ];
}
