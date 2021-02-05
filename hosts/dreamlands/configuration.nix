{ config, pkgs, lib, ... }:

with lib;

let
  concourseHttpPort = 3001;
  eventApiHttpPort  = 3002;
  frontendHttpPort  = 3003;
  giteaHttpPort     = 3000;
  registryHttpPort  = 5000;

  dockerComposeService = { name, yaml, pull ? "" }:
    let
      dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;
    in
      {
        enable   = true;
        wantedBy = [ "multi-user.target" ];
        requires = [ "docker.service" ];
        environment = { COMPOSE_PROJECT_NAME = name; };
        serviceConfig = mkMerge [
          (mkIf (pull != "") { ExecStartPre = "${pkgs.docker}/bin/docker pull registry.barrucadu.dev/${pull}"; })
          {
            ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
            ExecStop  = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
            Restart   = "always";
          }
        ];
      };

in

{
  networking.hostName = "dreamlands";

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Networking
  networking.firewall.allowedTCPPorts = [ 80 222 443 ];

  networking.interfaces.ens3 = {
    ipv6.addresses = [ { address = "2a01:4f8:c0c:77b3::"; prefixLength = 64; } ];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };

  # WWW
  services.caddy.enable = true;
  services.caddy.config = ''
    barrucadu.dev {
      redir https://www.barrucadu.dev{uri}
    }

    dreamlands.barrucadu.co.uk {
      redir https://www.barrucadu.dev{uri}
    }

    www.barrucadu.dev {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString frontendHttpPort}
    }

    registry.barrucadu.dev {
      encode gzip

      @writeaccess {
        path /v2/*
        not {
          method GET HEAD
        }
      }
      basicauth @writeaccess {
        registry ${fileContents /etc/nixos/secrets/registry-password-hashed.txt}
      }

      header /v2/* Docker-Distribution-Api-Version "registry/2.0"
      reverse_proxy /v2/* http://127.0.0.1:${toString registryHttpPort}
    }

    event-api.barrucadu.dev {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString eventApiHttpPort}
    }

    cd.barrucadu.dev {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString concourseHttpPort} {
        flush_interval -1
      }
    }

    git.barrucadu.dev {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString giteaHttpPort}
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
  security.sudo.extraRules = [
    {
      users = [ "concourse-deploy-robot" ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl restart event-api-server"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl restart frontend";         options = [ "NOPASSWD" ]; }
      ];
    }
  ];
  users.extraUsers.concourse-deploy-robot = {
    home = "/home/system/concourse-deploy-robot";
    createHome = true;
    isSystemUser = true;
    openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxmx52eoKFJmdkejuiLZ4ZMaQ/4GQsXADIORQdmmb8N concourse-worker@cd.barrucadu.dev" ];
    shell = pkgs.bashInteractive;
  };

  systemd.services.gitea = dockerComposeService {
    name = "gitea";
    yaml = import ./gitea.docker-compose.nix { httpPort = giteaHttpPort; };
  };

  systemd.services.frontend = dockerComposeService {
    name = "frontend";
    yaml = import ./frontend.docker-compose.nix { httpPort = frontendHttpPort; };
    pull = "frontend:latest";
  };

  systemd.services.event-api-server = dockerComposeService {
    name = "event-api-server";
    yaml = import ./event-api-server.docker-compose.nix {
      httpPort  = eventApiHttpPort;
      jwtSecret = fileContents /etc/nixos/secrets/event-api-server-jwt.txt;
    };
    pull = "event-api-server:latest";
  };
}
