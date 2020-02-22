{ config, pkgs, lib, ... }:

with lib;

let
  pullDevDockerImage = pkgs.writeShellScript "pull-dev-docker-image.sh" ''
    set -e
    set -o pipefail

    ${pkgs.coreutils}/bin/cat /etc/nixos/secrets/registry-password.txt | ${pkgs.docker}/bin/docker login --username registry --password-stdin https://registry.barrucadu.dev
    ${pkgs.docker}/bin/docker pull registry.barrucadu.dev/$1
  '';

in

{
  networking.hostName = "dunwich";

  # Bootloader
  boot.loader.grub.enable  = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device  = "/dev/sda";

  # Networking
  networking.firewall.allowedTCPPorts = [ 80 443 25565 ];

  networking.interfaces.ens3 = {
    ipv6.addresses = [ { address = "2a01:4f8:c2c:2b22::"; prefixLength = 64; } ];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "ens3"; };

  # Web server
  services.caddy.enable = true;
  services.caddy.enable-phpfpm-pool = true;
  services.caddy.config = ''
    (basics) {
      log / stdout "{host} {combined}"
      gzip
    }

    # add headers solely to look good if people run
    # securityheaders.com on my domains
    (security_theatre) {
      header / Access-Control-Allow-Origin "*"
      header / Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
      header / Referrer-Policy "strict-origin-when-cross-origin"
      header / Strict-Transport-Security "max-age=31536000; includeSubDomains"
      header / X-Content-Type-Options "nosniff"
      header / X-Frame-Options "SAMEORIGIN"
      header / X-XSS-Protection "1; mode=block"
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
      import basics
      root /srv/http/barrucadu.co.uk/www

      import security_theatre

      header /fonts     Cache-Control "public, immutable, max-age=31536000"
      header /logos     Cache-Control "public, immutable, max-age=31536000"
      header /style.css Cache-Control "public, max-age=604800"

      ${fileContents ./www-barrucadu-co-uk.caddyfile}
    }

    ap.barrucadu.co.uk {
      import basics

      proxy / http://127.0.0.1:${toString config.services.pleroma.port} {
        websocket
        transparent
      }
    }

    bookdb.barrucadu.co.uk {
      import basics

      proxy / http://127.0.0.1:3000 {
        header_downstream Access-Control-Allow-Origin "*"
        header_downstream Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'"
        header_downstream Referrer-Policy "strict-origin-when-cross-origin"
        header_downstream Strict-Transport-Security "max-age=31536000; includeSubDomains"
        header_downstream X-Content-Type-Options "nosniff"
        header_downstream X-Frame-Options "SAMEORIGIN"
        header_downstream X-XSS-Protection "1; mode=block"
      }
    }

    memo.barrucadu.co.uk {
      import basics
      root /srv/http/barrucadu.co.uk/memo

      header /fonts     Cache-Control "public, immutable, max-age=31536000"
      header /MathJax   Cache-Control "public, max-age=7776000"
      header /style.css Cache-Control "public, max-age=604800"
      header /code.css  Cache-Control "public, max-age=604800"

      import security_theatre
    }

    misc.barrucadu.co.uk {
      import basics
      root /srv/http/barrucadu.co.uk/misc

      import security_theatre

      mime {
        .md       text/plain
        .markdown text/plain
        .rst      text/plain
      }
    }

    uzbl.org {
      redir https://www.uzbl.org{uri}
    }

    www.uzbl.org {
      import basics
      index index.php
      root /srv/http/uzbl.org/www

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

      fastcgi / /run/phpfpm/caddy.sock php

      import security_theatre
    }

    http://*:80 {
      import basics
      status 421 /

      import security_theatre
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

  # bookdb
  services.bookdb.enable = true;
  services.bookdb.image = "registry.barrucadu.dev/bookdb:latest";
  services.bookdb.webRoot = "https://bookdb.barrucadu.co.uk";
  services.bookdb.readOnly = true;
  services.bookdb.execStartPre = "${pullDevDockerImage} bookdb:latest";

  # Databases
  services.mongodb.enable = true;

  # barrucadu.dev concourse access
  security.sudo.extraRules = [
    {
      users = [ "concourse-deploy-robot" ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl restart bookdb"; options = [ "NOPASSWD" ]; }
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
