{ config, lib, pkgs, ... }:

with lib;
let
  dockerRegistryPort = 3000;
  concoursePort = 3003;
  umamiPort = 3006;
  concourseMetricsPort = 3009;
  grafanaPort = 3010;
  foundryPort = 3011;

  httpdir = "${toString config.nixfiles.eraseYourDarlings.persistDir}/srv/http";
in
{
  ###############################################################################
  ## General
  ###############################################################################

  networking.hostId = "f62895cc";
  boot.supportedFilesystems = [ "zfs" ];

  # Bootloader
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  # Networking
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  networking.interfaces.enp1s0 = {
    ipv6.addresses = [{ address = "2a01:4f8:c0c:bfc1::"; prefixLength = 64; }];
  };
  networking.defaultGateway6 = { address = "fe80::1"; interface = "enp1s0"; };

  nixfiles.firewall.ipBlocklistFile = config.sops.secrets."nixfiles/firewall/ip_blocklist".path;
  sops.secrets."nixfiles/firewall/ip_blocklist" = { };

  # No automatic reboots (for irssi)
  system.autoUpgrade.allowReboot = mkForce false;

  # Wipe / on boot
  nixfiles.eraseYourDarlings.enable = true;
  nixfiles.eraseYourDarlings.machineId = "64b1b10f3bef4616a7faf5edf1ef3ca5";
  nixfiles.eraseYourDarlings.barrucaduPasswordFile = config.sops.secrets."users/barrucadu".path;
  sops.secrets."users/barrucadu".neededForUsers = true;

  # Monitoring
  services.prometheus.alertmanager.environmentFile = config.sops.secrets."services/alertmanager/env".path;
  sops.secrets."services/alertmanager/env" = { };


  ###############################################################################
  ## Backups
  ###############################################################################

  nixfiles.backups.enable = true;
  nixfiles.backups.environmentFile = config.sops.secrets."nixfiles/backups/env".path;
  nixfiles.backups.scripts.syncthing = "cp -a /home/barrucadu/s .";
  # TODO: this will break when I have >100 github repos
  nixfiles.backups.scripts.git = ''
    curl -u "barrucadu:''${GITHUB_TOKEN}" 'https://api.github.com/user/repos?type=owner&per_page=100' 2>/dev/null | \
      jq -r '.[].ssh_url' | \
      while read url; do
        git clone --bare "$url"
      done
  '';
  sops.secrets."nixfiles/backups/env" = { };


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
        root ${httpdir}/barrucadu.co.uk/www
      }

      ${fileContents ./caddy/www-barrucadu-co-uk.caddyfile}
    }

    bookdb.barrucadu.co.uk {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.nixfiles.bookdb.port}
    }

    bookmarks.barrucadu.co.uk {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.nixfiles.bookmarks.port}
    }

    foundry.barrucadu.co.uk {
      import common_config
      reverse_proxy http://localhost:${toString config.nixfiles.foundryvtt.port}
    }

    memo.barrucadu.co.uk {
      import common_config

      header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
      header /mathjax/* Cache-Control "public, immutable, max-age=7776000"
      header /*.css     Cache-Control "public, immutable, max-age=31536000"

      root * ${httpdir}/barrucadu.co.uk/memo
      file_server

      handle_errors {
        @410 {
          expression {http.error.status_code} == 410
        }
        rewrite @410 /410.html
        file_server
      }

      ${fileContents ./caddy/memo-barrucadu-co-uk.caddyfile}
    }

    misc.barrucadu.co.uk {
      import common_config
      basicauth /_site/* {
        import ${config.sops.secrets."services/caddy/fragments/misc_site".path}
      }

      @subdirectory path_regexp ^/(7day|14day|28day|forever)/[a-z0-9]

      root * ${httpdir}/barrucadu.co.uk/misc
      file_server @subdirectory browse
      file_server
    }

    grafana.carcosa.barrucadu.co.uk {
      import common_config
      reverse_proxy http://localhost:${toString config.services.grafana.settings.server.http_port}
    }

    prometheus.carcosa.barrucadu.co.uk {
      import common_config
      reverse_proxy http://localhost:${toString config.services.prometheus.port}
    }

    weeknotes.barrucadu.co.uk {
      import common_config

      header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
      header /*.css     Cache-Control "public, immutable, max-age=31536000"

      file_server  {
        root ${httpdir}/barrucadu.co.uk/weeknotes
      }
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
      reverse_proxy http://127.0.0.1:${toString config.nixfiles.concourse.port} {
        flush_interval -1
      }
    }

    registry.barrucadu.dev {
      import common_config
      basicauth /v2/* {
        import ${config.sops.secrets."services/caddy/fragments/registry".path}
      }
      header /v2/* Docker-Distribution-Api-Version "registry/2.0"
      reverse_proxy /v2/* http://127.0.0.1:${toString config.services.dockerRegistry.port}
    }

    lainon.life {
      import common_config

      root * ${./caddy/lainon-life}
      file_server

      handle_errors {
        @404 {
          expression {http.error.status_code} == 404
        }
        rewrite @404 /404.html
        file_server
      }
    }

    social.lainon.life {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.nixfiles.pleroma.port}
    }

    www.lainon.life {
      import common_config
      redir https://lainon.life{uri}
    }

    lookwhattheshoggothdraggedin.com {
      import common_config
      redir https://www.lookwhattheshoggothdraggedin.com{uri}
    }

    www.lookwhattheshoggothdraggedin.com {
      import common_config

      header Content-Security-Policy "default-src 'self' umami.lookwhattheshoggothdraggedin.com; style-src 'self' 'unsafe-inline'; img-src 'self' 'unsafe-inline' data:"

      header /files/*         Cache-Control "public, immutable, max-age=604800"
      header /fonts/*         Cache-Control "public, immutable, max-age=31536000"
      header /logo.png        Cache-Control "public, immutable, max-age=604800"
      header /*.css           Cache-Control "public, immutable, max-age=31536000"
      header /twitter-cards/* Cache-Control "public, immutable, max-age=604800"

      root * ${httpdir}/lookwhattheshoggothdraggedin.com/www
      file_server

      handle_errors {
        @404 {
          expression {http.error.status_code} == 404
        }
        rewrite @404 /404.html
        file_server
      }
    }

    umami.lookwhattheshoggothdraggedin.com {
      import common_config
      reverse_proxy http://127.0.0.1:${toString config.nixfiles.umami.port}
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

      root * ${httpdir}/uzbl.org/www
      php_fastcgi unix//run/phpfpm/caddy.sock
      file_server
    }
  '';
  sops.secrets."services/caddy/fragments/misc_site".owner = config.users.users.caddy.name;
  sops.secrets."services/caddy/fragments/registry".owner = config.users.users.caddy.name;

  services.phpfpm.pools.caddy = {
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
    "d ${httpdir}/barrucadu.co.uk/misc/_site 0755 barrucadu users  1d"
    "d ${httpdir}/barrucadu.co.uk/misc/7day  0755 barrucadu users  7d"
    "d ${httpdir}/barrucadu.co.uk/misc/14day 0755 barrucadu users 14d"
    "d ${httpdir}/barrucadu.co.uk/misc/28day 0755 barrucadu users 28d"
  ];

  # Docker registry
  services.dockerRegistry.enable = true;
  services.dockerRegistry.enableDelete = true;
  services.dockerRegistry.enableGarbageCollect = true;
  services.dockerRegistry.port = dockerRegistryPort;

  # bookdb
  nixfiles.bookdb.enable = true;
  nixfiles.bookdb.baseURI = "https://bookdb.barrucadu.co.uk";
  nixfiles.bookdb.readOnly = true;

  # bookmarks
  nixfiles.bookmarks.enable = true;
  nixfiles.bookmarks.baseURI = "https://bookmarks.barrucadu.co.uk";
  nixfiles.bookmarks.readOnly = true;

  # concourse
  nixfiles.concourse.enable = true;
  nixfiles.concourse.port = concoursePort;
  nixfiles.concourse.metricsPort = concourseMetricsPort;
  nixfiles.concourse.environmentFile = config.sops.secrets."nixfiles/concourse/env".path;
  nixfiles.concourse.workerScratchDir = "/var/concourse-worker-scratch";
  sops.secrets."nixfiles/concourse/env" = { };

  # Look what the Shoggoth Dragged In
  nixfiles.umami.enable = true;
  nixfiles.umami.port = umamiPort;
  nixfiles.umami.environmentFile = config.sops.secrets."nixfiles/umami/env".path;
  sops.secrets."nixfiles/umami/env" = { };

  # minecraft
  nixfiles.minecraft.enable = true;
  nixfiles.minecraft.servers.tea = {
    autoStart = false;
    port = 25565;
    jar = "fabric-server-launch.jar";
  };

  # Foundry VTT
  nixfiles.foundryvtt.enable = true;
  nixfiles.foundryvtt.port = foundryPort;

  # social.lainon.life
  nixfiles.pleroma.enable = true;
  nixfiles.pleroma.domain = "social.lainon.life";
  nixfiles.pleroma.faviconPath = ./pleroma-favicon.png;
  nixfiles.pleroma.secretsFile = config.sops.secrets."nixfiles/pleroma/exc".path;
  nixfiles.pleroma.allowRegistration = true;
  sops.secrets."nixfiles/pleroma/exc".owner = config.users.users.pleroma.name;


  ###############################################################################
  ## Nyarlathotep Sync
  ###############################################################################

  users.extraUsers.nyarlathotep-remote-sync = {
    home = "/var/lib/nyarlathotep-remote-sync";
    createHome = true;
    isSystemUser = true;
    openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChVw9DPLafA3lCLCI4Df9rYuxedFQTXAwDOOHUfZ0Ac remote-sync@nyarlathotep" ];
    shell = pkgs.bashInteractive;
    group = "nogroup";
    packages =
      let
        bookdb-receive-covers = ''
          if [[ ! -d ~/bookdb-covers ]]; then
            echo "bookdb-covers does not exist"
            exit 1
          fi

          /run/wrappers/bin/sudo rsync -a --delete ~/bookdb-covers/ ${config.nixfiles.bookdb.dataDir}/covers || exit 1
          /run/wrappers/bin/sudo chown -R ${config.users.users.bookdb.name}.nogroup ${config.nixfiles.bookdb.dataDir}/covers || exit 1
        '';
        bookdb-receive-elasticsearch = ''
          env ES_HOST=${config.systemd.services.bookdb.environment.ES_HOST} \
              DELETE_EXISTING_INDEX=1 \
              ${pkgs.nixfiles.bookdb}/bin/python -m bookdb.index.create -
        '';
        bookmarks-receive-elasticsearch = ''
          env ES_HOST=${config.systemd.services.bookmarks.environment.ES_HOST} \
              DELETE_EXISTING_INDEX=1 \
              ${pkgs.nixfiles.bookmarks}/bin/python -m bookmarks.index.create -
        '';
      in
      [
        (pkgs.writeShellScriptBin "bookdb-receive-covers" bookdb-receive-covers)
        (pkgs.writeShellScriptBin "bookdb-receive-elasticsearch" bookdb-receive-elasticsearch)
        (pkgs.writeShellScriptBin "bookmarks-receive-elasticsearch" bookmarks-receive-elasticsearch)
      ];
  };

  security.sudo.extraRules = [
    {
      users = [ config.users.extraUsers.nyarlathotep-remote-sync.name ];
      commands = [
        { command = "${pkgs.rsync}/bin/rsync -a --delete ${config.users.extraUsers.nyarlathotep-remote-sync.home}/bookdb-covers/ ${config.nixfiles.bookdb.dataDir}/covers"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.coreutils-full}/bin/chown -R ${config.users.users.bookdb.name}.nogroup ${config.nixfiles.bookdb.dataDir}/covers"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  ###############################################################################
  ## Miscellaneous
  ###############################################################################

  # Metrics
  services.grafana.settings = {
    server.http_port = grafanaPort;
    server.root_url = "https://grafana.carcosa.barrucadu.co.uk";
    security.admin_password = "$__file{${config.sops.secrets."services/grafana/admin_password".path}";
    security.secret_key = "$__file{${config.sops.secrets."services/grafana/secret_key".path}}";
  };
  sops.secrets."services/grafana/admin_password".owner = config.users.users.grafana.name;
  sops.secrets."services/grafana/secret_key".owner = config.users.users.grafana.name;

  services.prometheus.webExternalUrl = "https://prometheus.carcosa.barrucadu.co.uk";

  # Extra packages
  users.extraUsers.barrucadu.packages = with pkgs; [
    irssi
    perl
  ];
}
