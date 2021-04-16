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
    # add headers solely to look good if people run
    # securityheaders.com on my domains
    (security_theatre) {
      header * Access-Control-Allow-Origin "*"
      header * Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
      header * Referrer-Policy "strict-origin-when-cross-origin"
      header * Strict-Transport-Security "max-age=31536000; includeSubDomains"
      header * X-Content-Type-Options "nosniff"
      header * X-Frame-Options "SAMEORIGIN"
      header * X-XSS-Protection "1; mode=block"
    }
    (reverse_proxy_security_theatre) {
      header_down * Access-Control-Allow-Origin "*"
      header_down * Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
      header_down * Referrer-Policy "strict-origin-when-cross-origin"
      header_down * Strict-Transport-Security "max-age=31536000; includeSubDomains"
      header_down * X-Content-Type-Options "nosniff"
      header_down * X-Frame-Options "SAMEORIGIN"
      header_down * X-XSS-Protection "1; mode=block"
    }

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
      import security_theatre
      encode gzip

      header /fonts/* Cache-Control "public, immutable, max-age=31536000"
      header /*.css   Cache-Control "public, immutable, max-age=31536000"

      file_server {
        root /srv/http/barrucadu.co.uk/www
      }

      ${fileContents ./www-barrucadu-co-uk.caddyfile}
    }

    ${config.services.pleroma.domain} {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.pleroma.httpPort}
    }

    bookdb.barrucadu.co.uk {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.bookdb.httpPort} {
        import reverse_proxy_security_theatre
      }
    }

    bookmarks.barrucadu.co.uk {
      encode gzip
      reverse_proxy http://127.0.0.1:${toString config.services.bookmarks.httpPort} {
        import reverse_proxy_security_theatre
      }
    }

    memo.barrucadu.co.uk {
      import security_theatre
      encode gzip

      header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
      header /mathjax/* Cache-Control "public, immutable, max-age=7776000"
      header /*.css     Cache-Control "public, immutable, max-age=31536000"

      file_server  {
        root /srv/http/barrucadu.co.uk/memo
      }

      ${fileContents ./memo-barrucadu-co-uk.caddyfile}
    }

    misc.barrucadu.co.uk {
      import security_theatre
      encode gzip

      @subdirectory path_regexp ^/(7day|14day|28day|forever)/[a-z0-9]

      root * /srv/http/barrucadu.co.uk/misc
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

    lookwhattheshoggothdraggedin.com {
      redir https://www.lookwhattheshoggothdraggedin.com{uri}
    }

    www.lookwhattheshoggothdraggedin.com {
      import security_theatre
      header * Content-Security-Policy "default-src 'self' commento.lookwhattheshoggothdraggedin.com umami.lookwhattheshoggothdraggedin.com; style-src 'self' 'unsafe-inline' commento.lookwhattheshoggothdraggedin.com; img-src 'self' 'unsafe-inline' commento.lookwhattheshoggothdraggedin.com data:"

      encode gzip

      header /files/*         Cache-Control "public, immutable, max-age=604800"
      header /fonts/*         Cache-Control "public, immutable, max-age=31536000"
      header /logo.png        Cache-Control "public, immutable, max-age=604800"
      header /*.css           Cache-Control "public, immutable, max-age=31536000"
      header /twitter-cards/* Cache-Control "public, immutable, max-age=604800"

      root * /srv/http/lookwhattheshoggothdraggedin.com/www
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

  # Clear the misc files every so often
  systemd.tmpfiles.rules =
    [
      "d /srv/http/barrucadu.co.uk/misc/7day  0755 barrucadu users  7d"
      "d /srv/http/barrucadu.co.uk/misc/14day 0755 barrucadu users 14d"
      "d /srv/http/barrucadu.co.uk/misc/28day 0755 barrucadu users 28d"
    ];

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

  # bookdb
  services.bookdb.enable = true;
  services.bookdb.image = "registry.barrucadu.dev/bookdb:latest";
  services.bookdb.baseURI = "https://bookdb.barrucadu.co.uk";
  services.bookdb.readOnly = true;
  services.bookdb.execStartPre = "${pullDevDockerImage} bookdb:latest";
  services.bookdb.dockerVolumeDir = /persist/docker-volumes/bookdb;

  # bookmarks
  services.bookmarks.enable = true;
  services.bookmarks.image = "registry.barrucadu.dev/bookmarks:latest";
  services.bookmarks.baseURI = "https://bookmarks.barrucadu.co.uk";
  services.bookmarks.readOnly = true;
  services.bookmarks.execStartPre = "${pullDevDockerImage} bookmarks:latest";
  services.bookmarks.httpPort = 3003;
  services.bookmarks.dockerVolumeDir = /persist/docker-volumes/bookmarks;

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
        { command = "${pkgs.systemd}/bin/systemctl restart bookdb"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl restart bookmarks"; options = [ "NOPASSWD" ]; }
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
