{ config, pkgs, lib, ... }:

with lib;
let
  shoggothCommentoHttpPort = 3004;
  shoggothUmamiHttpPort = 3005;

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
    (reverse_proxy_security_theatre) {
      header_down * Access-Control-Allow-Origin "*"
      header_down * Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
      header_down * Referrer-Policy "strict-origin-when-cross-origin"
      header_down * Strict-Transport-Security "max-age=31536000; includeSubDomains"
      header_down * X-Content-Type-Options "nosniff"
      header_down * X-Frame-Options "SAMEORIGIN"
      header_down * X-XSS-Protection "1; mode=block"
    }

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

    commento.lookwhattheshoggothdraggedin.com {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString shoggothCommentoHttpPort} {
        import reverse_proxy_security_theatre
      }
    }

    umami.lookwhattheshoggothdraggedin.com {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString shoggothUmamiHttpPort} {
        import reverse_proxy_security_theatre
      }
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

  # Look what the Shoggoth Dragged In blog
  services.commento.enable = true;
  services.commento.httpPort = shoggothCommentoHttpPort;
  services.commento.externalUrl = "https://commento.lookwhattheshoggothdraggedin.com";
  services.commento.githubKey = fileContents /etc/nixos/secrets/shoggoth-commento/github-key.txt;
  services.commento.githubSecret = fileContents /etc/nixos/secrets/shoggoth-commento/github-secret.txt;
  services.commento.googleKey = fileContents /etc/nixos/secrets/shoggoth-commento/google-key.txt;
  services.commento.googleSecret = fileContents /etc/nixos/secrets/shoggoth-commento/google-secret.txt;
  services.commento.twitterKey = fileContents /etc/nixos/secrets/shoggoth-commento/twitter-key.txt;
  services.commento.twitterSecret = fileContents /etc/nixos/secrets/shoggoth-commento/twitter-secret.txt;
  services.commento.dockerVolumeDir = /persist/docker-volumes/commento;

  services.umami.enable = true;
  services.umami.httpPort = shoggothUmamiHttpPort;
  services.umami.hashSalt = fileContents /etc/nixos/secrets/shoggoth-umami/hash-salt.txt;
  services.umami.dockerVolumeDir = /persist/docker-volumes/umami;

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
