{ config, pkgs, lib, ... }:

with lib;

{
  networking.hostName = "dunwich";

  imports = [
    ../services/bookdb.nix
    ../services/caddy.nix
    ../services/concourseci.nix
    ../services/pleroma.nix
  ];

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
      header / Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self'"
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

    ${config.services.concourseci.domain} {
      import basics

      proxy / http://127.0.0.1:${toString config.services.concourseci.port} {
        websocket
        header_downstream Access-Control-Allow-Origin "*"
        header_downstream Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; font-src 'self' https://fonts.googleapis.com"
        header_downstream Referrer-Policy "strict-origin-when-cross-origin"
        header_downstream Strict-Transport-Security "max-age=31536000; includeSubDomains"
        header_downstream X-Content-Type-Options "nosniff"
        header_downstream X-Frame-Options "SAMEORIGIN"
        header_downstream X-XSS-Protection "1; mode=block"
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

  # bookdb
  services.bookdb.image = "ci-registry:5000/bookdb:latest";
  services.bookdb.webRoot = "https://bookdb.barrucadu.co.uk";
  services.bookdb.readOnly = true;

  # Databases
  services.mongodb.enable = true;

  # Gitolite
  services.gitolite =
    { enable = true
    ; user = "git"
    ; dataDir = "/srv/git"
    ; adminPubkey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDILnZ0gRTqD6QnPMs99717N+j00IEESLRYQJ33bJ8mn8kjfStwFYFhXvnVg7iLV1toJ/AeSV9jkCY/nVSSA00n2gg82jNPyNtKl5LJG7T5gCD+QaIbrJ7Vzc90wJ2CVHOE9Yk+2lpEWMRdCBLRa38fp3/XCapXnt++ej71WOP3YjweB45RATM30vjoZvgw4w486OOqhoCcBlqtiZ47oKTZZ7I2VcFJA0pzx2sbArDlWZwmyA4C0d+kQLH2+rAcoId8R6CE/8gsMUp8xdjg5r0ZxETKwhlwWaMxICcowDniExFQkBo98VbpdE/5BfAUDj4fZLgs/WRGXZwYWRCtJfrL barrucadu@azathoth"
    ; };
  # for backup scripts
  users.extraUsers.barrucadu.extraGroups = [ "gitolite" ];

  # Log files
  services.logrotate.enable = true;
  services.logrotate.config = ''
/var/spool/nginx/logs/access.log /var/spool/nginx/logs/error.log {
    weekly
    copytruncate
    rotate 4
    compress
    postrotate
        systemctl kill nginx.service --signal=USR1
    endscript
}
  '';

  # CI
  services.concourseci = {
    githubClientId = lib.fileContents /etc/nixos/secrets/concourse-github-client-id.txt;
    githubClientSecret = lib.fileContents /etc/nixos/secrets/concourse-github-client-secret.txt;
    domain = "ci.dunwich.barrucadu.co.uk";
    sshPublicKeys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK4Ns3Qlja6/CsRb7w9SghjDniKiA6ohv7JRg274cRBc concourseci+worker@ci.dunwich.barrucadu.co.uk" ];
  };
  # for deploying bookdb
  security.sudo.extraRules = [
    { commands = [ { command = "${pkgs.systemd}/bin/systemctl restart bookdb"; options = [ "NOPASSWD" ]; } ]; users = [ "concourseci" ]; }
  ];

  # 10% of the RAM is too little space
  services.logind.extraConfig = ''
    RuntimeDirectorySize=2G
  '';

  # Extra packages
  environment.systemPackages = with pkgs; [
    haskellPackages.hledger
    irssi
    perl
    texlive.combined.scheme-full
  ];
}
