{ config, pkgs, lib, ... }:

with lib;

let
  giteaHttpPort    = 3000;
  registryHttpPort = 5000;
in

{
  networking.hostName = "dreamlands";

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Networking
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  networking.interfaces.ens3 = {
    ipv6.addresses = [ { address = "2a01:4f8:c0c:77b3::"; prefixLength = 64; } ];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };

  # WWW
  services.caddy.enable = true;
  services.caddy.enable-phpfpm-pool = true;
  services.caddy.config = ''
    (basics) {
      log / stdout "{host} {combined}"
      gzip
    }

    registry.barrucadu.dev {
      import basics

      basicauth /v2 registry ${fileContents /etc/nixos/secrets/registry-password.txt}

      header /v2 Docker-Distribution-Api-Version "registry/2.0"

      proxy /v2 http://127.0.0.1:${toString registryHttpPort} {
        transparent
      }
    }

    git.barrucadu.dev {
      import basics

      proxy / http://127.0.0.1:${toString giteaHttpPort} {
        transparent
      }
    }
  '';

  # Docker registry
  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableDelete = true;
  services.dockerRegistry.enableGarbageCollect = true;
  services.dockerRegistry.garbageCollectDates = "daily";
  services.dockerRegistry.port = registryHttpPort;

  # Gitea
  systemd.services.gitea =
    let
      dockerComposeYaml = import ./gitea.docker-compose.nix { httpPort = giteaHttpPort; };
      dockerComposeFile = pkgs.writeText "docker-compose.yml" dockerComposeYaml;
    in
      {
        enable   = true;
        wantedBy = [ "multi-user.target" ];
        requires = [ "docker.service" ];
        environment = { COMPOSE_PROJECT_NAME = "gitea"; };
        serviceConfig = {
          ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
          ExecStop  = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
          Restart   = "always";
        };
      };
}
