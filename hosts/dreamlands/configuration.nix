{ lib, ... }:

with lib;
let
  concourseHttpPort = 3001;
  giteaHttpPort = 3000;
  registryHttpPort = 5000;
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
    barrucadu.dev {
      redir https://www.barrucadu.co.uk
    }

    www.barrucadu.dev {
      redir https://www.barrucadu.co.uk
    }

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

  services.concourse.enable = true;
  services.concourse.httpPort = concourseHttpPort;
  services.concourse.githubClientId = fileContents /etc/nixos/secrets/concourse-clientid.txt;
  services.concourse.githubClientSecret = fileContents /etc/nixos/secrets/concourse-clientsecret.txt;
  services.concourse.enableSSM = true;
  services.concourse.ssmAccessKey = fileContents /etc/nixos/secrets/concourse-ssm-access-key.txt;
  services.concourse.ssmSecretKey = fileContents /etc/nixos/secrets/concourse-ssm-secret-key.txt;
  services.concourse.dockerVolumeDir = /persist/docker-volumes/concourse;

  services.gitea.enable = true;
  services.gitea.httpPort = giteaHttpPort;
  services.gitea.dockerVolumeDir = /persist/docker-volumes/gitea;
}
