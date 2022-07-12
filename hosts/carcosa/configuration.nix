{ config, lib, pkgs, ... }:

with lib;
let
  dockerRegistryPort = 3000;
  bookdbPort = 3001;
  bookmarksPort = 3002;
  concoursePort = 3003;
  commentoPort = 3005;
  umamiPort = 3006;
  pleromaPort = 3007;
  concourseMetricsPort = 3009;
  grafanaPort = 3010;
  foundryPort = 3011;

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

  sops.defaultSopsFile = ./secrets.yaml;

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  # ZFS auto trim, scrub, & snapshot
  modules.zfsAutomation.enable = true;

  # Networking
  networking.firewall.allowedTCPPorts = [ 80 222 443 ];

  networking.interfaces.enp1s0 = {
    ipv6.addresses = [{ address = "2a01:4f8:c0c:bfc1::"; prefixLength = 64; }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "enp1s0"; };

  modules.firewall.ipBlocklist = import /etc/nixos/secrets/ip-blocklist.nix;

  # No automatic reboots (for irssi)
  system.autoUpgrade.allowReboot = mkForce false;

  # Wipe / on boot
  modules.eraseYourDarlings.enable = true;
  modules.eraseYourDarlings.machineId = "64b1b10f3bef4616a7faf5edf1ef3ca5";
  modules.eraseYourDarlings.barrucaduPasswordFile = config.sops.secrets."users/barrucadu".path;
  sops.secrets."users/barrucadu".neededForUsers = true;


  ###############################################################################
  ## Services
  ###############################################################################

  # WWW
  services.caddy.enable = true;
  services.caddy.extraConfig = ''
    (common_config) {
      encode gzip

      header Permissions-Policy "interest-cohort=()"
      header Referrer-Policy "strict-origin-when-cross-origin"
      header Strict-Transport-Security "max-age=31536000; includeSubDomains"
      header X-Content-Type-Options "nosniff"
      header X-Frame-Options "SAMEORIGIN"

      header -Server
    }

    barrucadu.co.uk {
      import common_config
      redir https://www.barrucadu.co.uk{uri}
    }

    barrucadu.com {
      import common_config
      redir https://www.barrucadu.co.uk{uri}
    }

    www.barrucadu.com {
      import common_config
      redir https://www.barrucadu.co.uk{uri}
    }

    barrucadu.uk {
      import common_config
      redir https://www.barrucadu.co.uk{uri}
    }

    www.barrucadu.uk {
      import common_config
      redir https://www.barrucadu.co.uk{uri}
    }

    www.barrucadu.co.uk {
      import common_config

      header /fonts/* Cache-Control "public, immutable, max-age=31536000"
      header /*.css   Cache-Control "public, immutable, max-age=31536000"

      file_server {
        root ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/barrucadu.co.uk/www
      }

      ${fileContents ./www-barrucadu-co-uk.caddyfile}
    }

    ap.barrucadu.co.uk {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.services.pleroma.httpPort}
    }

    bookdb.barrucadu.co.uk {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.services.bookdb.httpPort}
    }

    bookmarks.barrucadu.co.uk {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.services.bookmarks.httpPort}
    }

    foundry.barrucadu.co.uk {
      import common_config
      reverse_proxy http://localhost:${toString foundryPort}
    }

    memo.barrucadu.co.uk {
      import common_config

      header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
      header /mathjax/* Cache-Control "public, immutable, max-age=7776000"
      header /*.css     Cache-Control "public, immutable, max-age=31536000"

      file_server  {
        root ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/barrucadu.co.uk/memo
      }

      ${fileContents ./memo-barrucadu-co-uk.caddyfile}
    }

    misc.barrucadu.co.uk {
      import common_config

      @subdirectory path_regexp ^/(7day|14day|28day|forever)/[a-z0-9]

      root * ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/barrucadu.co.uk/misc
      file_server @subdirectory browse
      file_server
    }

    grafana.carcosa.barrucadu.co.uk {
      import common_config
      reverse_proxy http://localhost:${toString config.services.grafana.port}
    }

    prometheus.carcosa.barrucadu.co.uk {
      import common_config
      reverse_proxy http://localhost:${toString config.services.prometheus.port}
    }

    barrucadu.dev {
      import common_config
      redir https://www.barrucadu.co.uk
    }

    www.barrucadu.dev {
      import common_config
      redir https://www.barrucadu.co.uk
    }

    cd.barrucadu.dev {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.services.concourse.httpPort} {
        flush_interval -1
      }
    }

    registry.barrucadu.dev {
      import common_config
      basicauth /v2/* {
        registry ${fileContents /etc/nixos/secrets/registry-password-hashed.txt}
      }
      header /v2/* Docker-Distribution-Api-Version "registry/2.0"
      reverse_proxy /v2/* http://127.0.0.1:${toString config.services.dockerRegistry.port}
    }

    lookwhattheshoggothdraggedin.com {
      import common_config
      redir https://www.lookwhattheshoggothdraggedin.com{uri}
    }

    www.lookwhattheshoggothdraggedin.com {
      import common_config

      header Content-Security-Policy "default-src 'self' commento.lookwhattheshoggothdraggedin.com umami.lookwhattheshoggothdraggedin.com; style-src 'self' 'unsafe-inline' commento.lookwhattheshoggothdraggedin.com; img-src 'self' 'unsafe-inline' commento.lookwhattheshoggothdraggedin.com data:"

      header /files/*         Cache-Control "public, immutable, max-age=604800"
      header /fonts/*         Cache-Control "public, immutable, max-age=31536000"
      header /logo.png        Cache-Control "public, immutable, max-age=604800"
      header /*.css           Cache-Control "public, immutable, max-age=31536000"
      header /twitter-cards/* Cache-Control "public, immutable, max-age=604800"

      root * ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/lookwhattheshoggothdraggedin.com/www
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
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.services.commento.httpPort}
    }

    umami.lookwhattheshoggothdraggedin.com {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.services.umami.httpPort}
    }

    uzbl.org {
      import common_config
      redir https://www.uzbl.org{uri}
    }

    www.uzbl.org {
      import common_config

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

      root * ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/uzbl.org/www
      php_fastcgi unix//run/phpfpm/caddy.sock
      file_server
    }
  '';

  services.phpfpm.pools.caddy = {
    phpPackage = pkgs.php74;
    user = "caddy";
    group = "caddy";
    settings = {
      "listen" = "/run/phpfpm/caddy.sock";
      "listen.owner" = "caddy";
      "listen.group" = "caddy";
      "pm" = "dynamic";
      "pm.max_children" = "5";
      "pm.start_servers" = "2";
      "pm.min_spare_servers" = "1";
      "pm.max_spare_servers" = "3";
    };
  };

  systemd.tmpfiles.rules = [
    "d ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/barrucadu.co.uk/misc/7day  0755 barrucadu users  7d"
    "d ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/barrucadu.co.uk/misc/14day 0755 barrucadu users 14d"
    "d ${toString config.modules.eraseYourDarlings.persistDir}/srv/http/barrucadu.co.uk/misc/28day 0755 barrucadu users 28d"
  ];

  # Docker registry
  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableDelete = true;
  services.dockerRegistry.enableGarbageCollect = true;
  services.dockerRegistry.port = dockerRegistryPort;

  # bookdb
  services.bookdb.enable = true;
  services.bookdb.image = "registry.barrucadu.dev/bookdb:latest";
  services.bookdb.baseURI = "https://bookdb.barrucadu.co.uk";
  services.bookdb.readOnly = true;
  services.bookdb.execStartPre = "${pullDevDockerImage} bookdb:latest";
  services.bookdb.httpPort = bookdbPort;

  # bookmarks
  services.bookmarks.enable = true;
  services.bookmarks.image = "registry.barrucadu.dev/bookmarks:latest";
  services.bookmarks.baseURI = "https://bookmarks.barrucadu.co.uk";
  services.bookmarks.readOnly = true;
  services.bookmarks.execStartPre = "${pullDevDockerImage} bookmarks:latest";
  services.bookmarks.httpPort = bookmarksPort;

  # pleroma
  services.pleroma.enable = true;
  services.pleroma.image = "registry.barrucadu.dev/pleroma:latest";
  services.pleroma.httpPort = pleromaPort;
  services.pleroma.domain = "ap.barrucadu.co.uk";
  services.pleroma.secretsFile = config.sops.secrets."services/pleroma/exc".path;
  services.pleroma.execStartPre = "${pullDevDockerImage} pleroma:latest";
  # TODO: figure out how to lock this down so only the pleroma process
  # can read it (remap the container UID / GID to something known,
  # perhaps?)
  sops.secrets."services/pleroma/exc".mode = "0444";

  # concourse
  services.concourse.enable = true;
  services.concourse.httpPort = concoursePort;
  services.concourse.metricsPort = concourseMetricsPort;
  services.concourse.environmentFile = config.sops.secrets."services/concourse/env".path;
  services.concourse.workerScratchDir = "/var/concourse-worker-scratch";
  sops.secrets."services/concourse/env" = { };

  # Look what the Shoggoth Dragged In
  services.commento.enable = true;
  services.commento.httpPort = commentoPort;
  services.commento.externalUrl = "https://commento.lookwhattheshoggothdraggedin.com";
  services.commento.environmentFile = config.sops.secrets."services/commento/env".path;
  sops.secrets."services/commento/env" = { };

  services.umami.enable = true;
  services.umami.httpPort = umamiPort;
  services.umami.environmentFile = config.sops.secrets."services/umami/env".path;
  sops.secrets."services/umami/env" = { };

  # minecraft
  services.minecraft.enable = true;
  services.minecraft.servers.tea = {
    port = 25565;
    jar = "fabric-server-launch.jar";
  };

  # Foundry VTT
  systemd.services.foundryvtt = {
    enable = true;
    description = "Foundry Virtual Tabletop";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.nodejs-18_x}/bin/node resources/app/main.js --dataPath=/persist/srv/foundry/data --port=${toString foundryPort}";
      Restart = "always";
      User = "foundryvtt";
      WorkingDirectory = "/persist/srv/foundry/bin";
    };
  };
  users.users.foundryvtt = {
    description = "Foundry VTT service user";
    home = "/persist/srv/foundry";
    createHome = true;
    isSystemUser = true;
    group = "nogroup";
  };


  ###############################################################################
  ## Miscellaneous
  ###############################################################################

  # Metrics
  services.grafana.port = grafanaPort;
  services.grafana.rootUrl = "https://grafana.carcosa.barrucadu.co.uk";
  services.grafana.security.adminPasswordFile = config.sops.secrets."services/grafana/admin_password".path;
  services.grafana.security.secretKeyFile = config.sops.secrets."services/grafana/secret_key".path;
  sops.secrets."services/grafana/admin_password".owner = config.users.users.grafana.name;
  sops.secrets."services/grafana/secret_key".owner = config.users.users.grafana.name;

  services.prometheus.webExternalUrl = "https://prometheus.carcosa.barrucadu.co.uk";

  # Concourse access
  users.extraUsers.concourse-deploy-robot = {
    home = "/home/system/concourse-deploy-robot";
    createHome = true;
    isSystemUser = true;
    openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFilTWek5xNpl82V48oQ99briJhn9BqwCACeRq1dQnZn concourse-worker@cd.barrucadu.dev" ];
    shell = pkgs.bashInteractive;
    group = "nogroup";
  };
  security.sudo.extraRules = [
    {
      users = [ "concourse-deploy-robot" ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl restart docker-bookdb"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl restart docker-bookmarks"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl restart docker-pleroma"; options = [ "NOPASSWD" ]; }
      ];
    }
    # for backup scripts
    {
      users = [ "barrucadu" ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl stop foundryvtt"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl start foundryvtt"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.gnutar}/bin/tar cfz foundryvtt.tar.gz /persist/srv/foundry"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.coreutils}/bin/chown barrucadu.users foundryvtt.tar.gz"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  # Extra packages
  environment.systemPackages = with pkgs; [
    irssi
    perl
  ];
}
