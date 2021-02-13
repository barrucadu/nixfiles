{ config, pkgs, lib, ... }:

with lib;

let
  shoggothCommentoHttpPort = 3004;
  shoggothUmamiHttpPort = 3005;

  dockerComposeService = { name, yaml }:
    let
      dockerComposeFile = pkgs.writeText "docker-compose.yml" yaml;
    in
      {
        enable   = true;
        wantedBy = [ "multi-user.target" ];
        requires = [ "docker.service" ];
        environment = { COMPOSE_PROJECT_NAME = name; };
        serviceConfig = mkMerge [
          {
            ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
            ExecStop  = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' stop";
            Restart   = "always";
          }
        ];
      };

in

{
  networking.hostName = "dunwich";

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Networking
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  networking.interfaces.ens3 = {
    ipv6.addresses = [ { address = "2a01:4f8:c2c:2b22::"; prefixLength = 64; } ];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };

  # Web server
  services.caddy.enable = true;
  services.caddy.enable-phpfpm-pool = true;
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

      header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
      header /logos/*   Cache-Control "public, immutable, max-age=31536000"
      header /style.css Cache-Control "public, max-age=604800"

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
      header /MathJax/* Cache-Control "public, max-age=7776000"
      header /style.css Cache-Control "public, max-age=604800"
      header /code.css  Cache-Control "public, max-age=604800"

      file_server  {
        root /srv/http/barrucadu.co.uk/memo
      }
    }

    misc.barrucadu.co.uk {
      import security_theatre
      encode gzip

      @subdirectory path_regexp ^/(7day|14day|28day|forever)/[a-z0-9]

      root * /srv/http/barrucadu.co.uk/misc
      file_server @subdirectory browse
      file_server
    }

    lookwhattheshoggothdraggedin.com {
      redir https://www.lookwhattheshoggothdraggedin.com{uri}
    }

    www.lookwhattheshoggothdraggedin.com {
      import security_theatre
      header * Content-Security-Policy "default-src 'self' commento.lookwhattheshoggothdraggedin.com umami.lookwhattheshoggothdraggedin.com; style-src 'self' 'unsafe-inline' commento.lookwhattheshoggothdraggedin.com; img-src 'self' 'unsafe-inline' commento.lookwhattheshoggothdraggedin.com data:"

      encode gzip

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

    uzbl.org {
      redir https://www.uzbl.org{uri}
    }

    www.uzbl.org {
      import security_theatre
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

      root * /srv/http/uzbl.org/www
      php_fastcgi unix//run/phpfpm/caddy.sock
      file_server
    }
  '';

  # Clear the misc files every so often
  systemd.tmpfiles.rules =
    [ "d /srv/http/barrucadu.co.uk/misc/7day  0755 barrucadu users  7d"
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
  services.pleroma.execStartPre = "${pkgs.docker}/bin/docker pull registry.barrucadu.dev/pleroma:latest";

  # bookdb
  services.bookdb.enable = true;
  services.bookdb.image = "registry.barrucadu.dev/bookdb:latest";
  services.bookdb.baseURI = "https://bookdb.barrucadu.co.uk";
  services.bookdb.readOnly = true;
  services.bookdb.execStartPre = "${pkgs.docker}/bin/docker pull registry.barrucadu.dev/bookdb:latest";

  # bookmarks
  services.bookmarks.enable = true;
  services.bookmarks.image = "registry.barrucadu.dev/bookmarks:latest";
  services.bookmarks.baseURI = "https://bookmarks.barrucadu.co.uk";
  services.bookmarks.readOnly = true;
  services.bookmarks.execStartPre = "${pkgs.docker}/bin/docker pull registry.barrucadu.dev/bookmarks:latest";
  services.bookmarks.httpPort = 3003;

  # minecraft
  services.minecraft.enable = true;

  # Look what the Shoggoth Dragged In blog
  systemd.services.shoggoth-commento = dockerComposeService {
    name = "shoggoth-commento";
    yaml = import ./commento.docker-compose.nix {
      httpPort = shoggothCommentoHttpPort;
      externalUrl = "https://commento.lookwhattheshoggothdraggedin.com";
      githubKey = fileContents /etc/nixos/secrets/shoggoth-commento/github-key.txt;
      githubSecret = fileContents /etc/nixos/secrets/shoggoth-commento/github-secret.txt;
      googleKey = fileContents /etc/nixos/secrets/shoggoth-commento/google-key.txt;
      googleSecret = fileContents /etc/nixos/secrets/shoggoth-commento/google-secret.txt;
      twitterKey = fileContents /etc/nixos/secrets/shoggoth-commento/twitter-key.txt;
      twitterSecret = fileContents /etc/nixos/secrets/shoggoth-commento/twitter-secret.txt;
    };
  };
  systemd.services.shoggoth-umami = dockerComposeService {
    name = "shoggoth-umami";
    yaml = import ./umami.docker-compose.nix {
      httpPort = shoggothUmamiHttpPort;
      hashSalt = fileContents /etc/nixos/secrets/shoggoth-umami/hash-salt.txt;
    };
  };


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
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID9mdg79dtI9KqxTOG2ATdnKXGhuQaqp2n3mXZ0brPuc concourse-worker@cd.barrucadu.dev" ];
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
