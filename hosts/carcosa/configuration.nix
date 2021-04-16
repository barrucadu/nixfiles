{ config, lib, pkgs, ... }:

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
  services.caddy.enable-phpfpm-pool = true;
  services.caddy.config = ''
    registry.barrucadu.dev {
      encode gzip
      basicauth /v2/* {
        registry ${fileContents /etc/nixos/secrets/registry-password-hashed.txt}
      }
      header /v2/* Docker-Distribution-Api-Version "registry/2.0"
      reverse_proxy /v2/* http://127.0.0.1:${toString config.services.dockerRegistry.port}
    }

    uzbl.org {
      redir https://www.uzbl.org{uri}
    }

    www.uzbl.org {
      encode gzip

      rewrite /archives.php    /index.php
      rewrite /faq.php         /index.php
      rewrite /readme.php      /index.php
      rewrite /keybindings.php /index.php
      rewrite /get.php         /index.php
      rewrite /community.php   /index.php
      rewrite /contribute.php  /index.php
      rewrite /commits.php     /index.php
      rewrite /news.php        /index.php
      rewrite /doesitwork/     /index.php
      rewrite /fosdem2010/     /index.php

      redir /doesitwork /doesitwork/
      redir /fosdem2020 /fosdem2020/

      root * /persist/srv/http/uzbl.org/www
      php_fastcgi unix//run/phpfpm/caddy.sock
      file_server
    }
  '';

  # Docker registry
  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableDelete = true;
  services.dockerRegistry.enableGarbageCollect = true;
  services.dockerRegistry.garbageCollectDates = "daily";
  services.dockerRegistry.storagePath = "/persist/var/lib/docker-registry";
  services.dockerRegistry.port = dockerRegistryPort;


  ###############################################################################
  ## Miscellaneous
  ###############################################################################

  # Concourse access
  users.extraUsers.concourse-deploy-robot = {
    home = "/home/system/concourse-deploy-robot";
    createHome = true;
    isSystemUser = true;
    openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFilTWek5xNpl82V48oQ99briJhn9BqwCACeRq1dQnZn concourse-worker@cd.barrucadu.dev" ];
    shell = pkgs.bashInteractive;
  };
}
