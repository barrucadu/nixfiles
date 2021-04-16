{ lib, ... }:

with lib;
let
  concourseHttpPort = 3001;
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
    barrucadu.dev {
      redir https://www.barrucadu.co.uk
    }

    www.barrucadu.dev {
      redir https://www.barrucadu.co.uk
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
