{ config, pkgs, lib, ... }:

with lib;

let
  concourseHttpPort = 3001;
  giteaHttpPort     = 3000;
  registryHttpPort  = 5000;

  dockerComposeService = { name, yaml }:
    let
      dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;
    in
      {
        enable   = true;
        wantedBy = [ "multi-user.target" ];
        requires = [ "docker.service" ];
        environment = { COMPOSE_PROJECT_NAME = name; };
        serviceConfig = {
          ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
          ExecStop  = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
          Restart   = "always";
        };
      };

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

    cd.barrucadu.dev {
      import basics

      proxy / http://127.0.0.1:${toString concourseHttpPort} {
        transparent
        websocket
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

  systemd.services.concourse = dockerComposeService {
    name = "concourse";
    yaml = import ./concourse.docker-compose.nix {
      httpPort = concourseHttpPort;
      githubClientId     = fileContents /etc/nixos/secrets/concourse-clientid.txt;
      githubClientSecret = fileContents /etc/nixos/secrets/concourse-clientsecret.txt;
    };
  };

  systemd.services.gitea = dockerComposeService {
    name = "gitea";
    yaml = import ./gitea.docker-compose.nix { httpPort = giteaHttpPort; };
  };
}
