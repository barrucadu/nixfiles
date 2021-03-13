{ config, pkgs, lib, ... }:

with lib;

let
  concourseHttpPort = 3001;
  giteaHttpPort     = 3000;
  registryHttpPort  = 5000;

  pullLocalDockerImage = pkgs.writeShellScript "pull-local-docker-image.sh" ''
    set -e
    set -o pipefail

    ${pkgs.coreutils}/bin/cat /etc/nixos/secrets/registry-password.txt | ${pkgs.docker}/bin/docker login --username registry --password-stdin https://registry.barrucadu.dev
    ${pkgs.docker}/bin/docker pull registry.barrucadu.dev/$1
  '';

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
          (mkIf (pull != "") { ExecStartPre = "${pullLocalDockerImage} ${pull}"; })
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
    registry.barrucadu.dev {
      encode gzip
      basicauth /v2/* {
        registry ${fileContents /etc/nixos/secrets/registry-password-hashed.txt}
      }
      header /v2/* Docker-Distribution-Api-Version "registry/2.0"
      reverse_proxy /v2/* http://127.0.0.1:${toString registryHttpPort}
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
      enableSSM = true;
      ssmAccessKey = fileContents /etc/nixos/secrets/concourse-ssm-access-key.txt;
      ssmSecretKey = fileContents /etc/nixos/secrets/concourse-ssm-secret-key.txt;
    };
  };

  systemd.services.gitea = dockerComposeService {
    name = "gitea";
    yaml = import ./gitea.docker-compose.nix { httpPort = giteaHttpPort; };
  };
}
