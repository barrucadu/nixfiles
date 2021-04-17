{ config, lib, pkgs, ... }:

with lib;
let
  dockerRegistryPort = 3000;
  bookdbPort = 3001;
  bookmarksPort = 3002;
  concoursePort = 3003;
  giteaPort = 3004;
  commentoPort = 3005;
  umamiPort = 3006;
  pleromaPort = 3007;
  etherpadPort = 3008;

  pullDevDockerImage = pkgs.writeShellScript "pull-dev-docker-image.sh" ''
    set -e
    set -o pipefail

    ${pkgs.coreutils}/bin/cat /etc/nixos/secrets/registry-password.txt | ${pkgs.docker}/bin/docker login --username registry --password-stdin https://registry.barrucadu.dev
    ${pkgs.docker}/bin/docker pull registry.barrucadu.dev/$1
  '';

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
  networking.firewall.allowedTCPPorts = [ 80 222 443 ];
  networking.firewall.trustedInterfaces = [ "lo" "docker0" ];

  networking.interfaces.enp1s0 = {
    ipv6.addresses = [{ address = "2a01:4f8:c0c:bfc1::"; prefixLength = 64; }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "enp1s0"; };

  # No automatic reboots (for irssi)
  system.autoUpgrade.allowReboot = mkForce false;


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
    "d /persist/srv/http/barrucadu.co.uk/misc/7day  0755 barrucadu users  7d"
    "d /persist/srv/http/barrucadu.co.uk/misc/14day 0755 barrucadu users 14d"
    "d /persist/srv/http/barrucadu.co.uk/misc/28day 0755 barrucadu users 28d"
  ];


  ###############################################################################
  ## Services
  ###############################################################################

  # WWW
  services.caddy.enable = true;
  services.caddy.enable-phpfpm-pool = true;
  services.caddy.config = ''
    barrucadu.co.uk {
      redir https://www.barrucadu.co.uk{uri}
    }

    barrucadu.com {
      redir https://www.barrucadu.co.uk{uri}
    }

    www.barrucadu.com {
      redir https://www.barrucadu.co.uk{uri}
    }

    barrucadu.uk {
      redir https://www.barrucadu.co.uk{uri}
    }

    www.barrucadu.uk {
      redir https://www.barrucadu.co.uk{uri}
    }

    www.barrucadu.co.uk {
      encode gzip

      header /fonts/* Cache-Control "public, immutable, max-age=31536000"
      header /*.css   Cache-Control "public, immutable, max-age=31536000"

      file_server {
        root /persist/srv/http/barrucadu.co.uk/www
      }

      ${fileContents ./www-barrucadu-co-uk.caddyfile}
    }

    ap.barrucadu.co.uk {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.pleroma.httpPort}
    }

    bookdb.barrucadu.co.uk {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.bookdb.httpPort}
    }

    bookmarks.barrucadu.co.uk {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.bookmarks.httpPort}
    }

    memo.barrucadu.co.uk {
      encode gzip

      header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
      header /mathjax/* Cache-Control "public, immutable, max-age=7776000"
      header /*.css     Cache-Control "public, immutable, max-age=31536000"

      file_server  {
        root /persist/srv/http/barrucadu.co.uk/memo
      }

      ${fileContents ./memo-barrucadu-co-uk.caddyfile}
    }

    misc.barrucadu.co.uk {
      encode gzip

      @subdirectory path_regexp ^/(7day|14day|28day|forever)/[a-z0-9]

      root * /persist/srv/http/barrucadu.co.uk/misc
      file_server @subdirectory browse
      file_server
    }

    pad.barrucadu.co.uk {
      basicauth {
        ${fileContents /etc/nixos/secrets/etherpad-basic-auth-credentials.txt}
      }

      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.etherpad.httpPort}
    }

    barrucadu.dev {
      redir https://www.barrucadu.co.uk
    }

    www.barrucadu.dev {
      redir https://www.barrucadu.co.uk
    }

    cd.barrucadu.dev {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.concourse.httpPort} {
        flush_interval -1
      }
    }

    git.barrucadu.dev {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.gitea.httpPort}
    }

    registry.barrucadu.dev {
      encode gzip
      basicauth /v2/* {
        registry ${fileContents /etc/nixos/secrets/registry-password-hashed.txt}
      }
      header /v2/* Docker-Distribution-Api-Version "registry/2.0"
      reverse_proxy /v2/* http://127.0.0.1:${toString config.services.dockerRegistry.port}
    }

    lookwhattheshoggothdraggedin.com {
      redir https://www.lookwhattheshoggothdraggedin.com{uri}
    }

    www.lookwhattheshoggothdraggedin.com {
      header * Content-Security-Policy "default-src 'self' commento.lookwhattheshoggothdraggedin.com umami.lookwhattheshoggothdraggedin.com; style-src 'self' 'unsafe-inline' commento.lookwhattheshoggothdraggedin.com; img-src 'self' 'unsafe-inline' commento.lookwhattheshoggothdraggedin.com data:"

      encode gzip

      header /files/*         Cache-Control "public, immutable, max-age=604800"
      header /fonts/*         Cache-Control "public, immutable, max-age=31536000"
      header /logo.png        Cache-Control "public, immutable, max-age=604800"
      header /*.css           Cache-Control "public, immutable, max-age=31536000"
      header /twitter-cards/* Cache-Control "public, immutable, max-age=604800"

      root * /persist/srv/http/lookwhattheshoggothdraggedin.com/www
      file_server

      handle_errors {
        @404 {
          expression {http.error.status_code} == 404
        }
        rewrite @404 /404.html
        file_server
      }
    }

    commento.lookwhattheshoggothdraggedin.com {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.commento.httpPort}
    }

    umami.lookwhattheshoggothdraggedin.com {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.umami.httpPort}
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

  # bookdb
  services.bookdb.enable = true;
  services.bookdb.image = "registry.barrucadu.dev/bookdb:latest";
  services.bookdb.baseURI = "https://bookdb.barrucadu.co.uk";
  services.bookdb.readOnly = true;
  services.bookdb.execStartPre = "${pullDevDockerImage} bookdb:latest";
  services.bookdb.dockerVolumeDir = "/persist/docker-volumes/bookdb";
  services.bookdb.httpPort = bookdbPort;

  # bookmarks
  services.bookmarks.enable = true;
  services.bookmarks.image = "registry.barrucadu.dev/bookmarks:latest";
  services.bookmarks.baseURI = "https://bookmarks.barrucadu.co.uk";
  services.bookmarks.readOnly = true;
  services.bookmarks.execStartPre = "${pullDevDockerImage} bookmarks:latest";
  services.bookmarks.dockerVolumeDir = "/persist/docker-volumes/bookmarks";
  services.bookmarks.httpPort = bookmarksPort;

  # pleroma
  services.pleroma.enable = true;
  services.pleroma.image = "registry.barrucadu.dev/pleroma:latest";
  services.pleroma.httpPort = pleromaPort;
  services.pleroma.domain = "ap.barrucadu.co.uk";
  services.pleroma.secretKeyBase = fileContents /etc/nixos/secrets/pleroma/secret-key-base.txt;
  services.pleroma.signingSalt = fileContents /etc/nixos/secrets/pleroma/signing-salt.txt;
  services.pleroma.webPushPublicKey = fileContents /etc/nixos/secrets/pleroma/web-push-public-key.txt;
  services.pleroma.webPushPrivateKey = fileContents /etc/nixos/secrets/pleroma/web-push-private-key.txt;
  services.pleroma.execStartPre = "${pullDevDockerImage} pleroma:latest";
  services.pleroma.dockerVolumeDir = "/persist/docker-volumes/pleroma";

  # etherpad
  services.etherpad.enable = true;
  services.etherpad.image = "etherpad/etherpad:stable";
  services.etherpad.httpPort = etherpadPort;
  services.etherpad.dockerVolumeDir = "/persist/docker-volumes/etherpad";

  # concourse
  services.concourse.enable = true;
  services.concourse.httpPort = concoursePort;
  services.concourse.githubClientId = fileContents /etc/nixos/secrets/concourse-clientid.txt;
  services.concourse.githubClientSecret = fileContents /etc/nixos/secrets/concourse-clientsecret.txt;
  services.concourse.enableSSM = true;
  services.concourse.ssmAccessKey = fileContents /etc/nixos/secrets/concourse-ssm-access-key.txt;
  services.concourse.ssmSecretKey = fileContents /etc/nixos/secrets/concourse-ssm-secret-key.txt;
  services.concourse.dockerVolumeDir = "/persist/docker-volumes/concourse";
  services.concourse.workerScratchDir = "/var/concourse-worker-scratch";

  # gitea
  services.gitea.enable = true;
  services.gitea.httpPort = giteaPort;
  services.gitea.dockerVolumeDir = "/persist/docker-volumes/gitea";

  # Look what the Shoggoth Dragged In
  services.commento.enable = true;
  services.commento.httpPort = commentoPort;
  services.commento.externalUrl = "https://commento.lookwhattheshoggothdraggedin.com";
  services.commento.githubKey = fileContents /etc/nixos/secrets/shoggoth-commento/github-key.txt;
  services.commento.githubSecret = fileContents /etc/nixos/secrets/shoggoth-commento/github-secret.txt;
  services.commento.googleKey = fileContents /etc/nixos/secrets/shoggoth-commento/google-key.txt;
  services.commento.googleSecret = fileContents /etc/nixos/secrets/shoggoth-commento/google-secret.txt;
  services.commento.twitterKey = fileContents /etc/nixos/secrets/shoggoth-commento/twitter-key.txt;
  services.commento.twitterSecret = fileContents /etc/nixos/secrets/shoggoth-commento/twitter-secret.txt;
  services.commento.dockerVolumeDir = "/persist/docker-volumes/commento";

  services.umami.enable = true;
  services.umami.httpPort = umamiPort;
  services.umami.hashSalt = fileContents /etc/nixos/secrets/shoggoth-umami/hash-salt.txt;
  services.umami.dockerVolumeDir = "/persist/docker-volumes/umami";

  # minecraft
  services.minecraft.enable = true;
  services.minecraft.dataDir = "/persist/srv/minecraft";


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
  security.sudo.extraRules = [
    {
      users = [ "concourse-deploy-robot" ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl restart bookdb"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl restart bookmarks"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl restart pleroma"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];
}
