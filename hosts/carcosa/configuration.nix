# This is a VPS (hosted by Hetzner Cloud).
#
# It serves [barrucadu.co.uk][] and other services on it.  Websites are served
# with Caddy, with certs from Let's Encrypt.
#
# It's set up in "erase your darlings" style, so most of the filesystem is wiped
# on boot and restored from the configuration, to ensure there's no accidentally
# unmanaged configuration or state hanging around.  However, it doesn't reboot
# automatically, because I also use this server for a persistent IRC connection.
#
# **Alerting:** enabled (standard only)
#
# **Backups:** enabled (standard + extras)
#
# **Public hostname:** `carcosa.barrucadu.co.uk`
#
# **Role:** server
#
# [barrucadu.co.uk]: https://www.barrucadu.co.uk/
{ config, lib, pkgs, ... }:

with lib;
let
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

  nixfiles.restic-backups.enable = true;
  nixfiles.restic-backups.environmentFile = config.sops.secrets."nixfiles/restic-backups/env".path;
  nixfiles.restic-backups.backups.github = {
    # TODO: this will break when I have >100 github repos
    # TODO: use a backup-specific SSH key?
    prepareCommand = ''
      ${pkgs.coreutils}/bin/mkdir repositories
      cd repositories

      ${pkgs.curl}/bin/curl -u "barrucadu:''${GITHUB_TOKEN}" 'https://api.github.com/user/repos?type=owner&per_page=100' 2>/dev/null | \
        ${pkgs.jq}/bin/jq -r '.[].ssh_url' | \
        while read url; do
          env GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i /home/barrucadu/.ssh/id_ed25519" \
            ${pkgs.git}/bin/git clone --bare "$url"
        done
    '';
    paths = [
      "repositories"
    ];
  };
  nixfiles.restic-backups.backups.syncthing = {
    paths = [
      "/home/barrucadu/s"
    ];
  };
  sops.secrets."nixfiles/restic-backups/env" = { };


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
  '';

  services.caddy.virtualHosts."barrucadu.co.uk".extraConfig = ''
    import common_config
    redir https://www.barrucadu.co.uk{uri}
  '';

  services.caddy.virtualHosts."barrucadu.com".extraConfig = ''
    import common_config
    redir https://www.barrucadu.co.uk{uri}
  '';

  services.caddy.virtualHosts."www.barrucadu.com".extraConfig = ''
    import common_config
    redir https://www.barrucadu.co.uk{uri}
  '';

  services.caddy.virtualHosts."barrucadu.uk".extraConfig = ''
    import common_config
    redir https://www.barrucadu.co.uk{uri}
  '';

  services.caddy.virtualHosts."www.barrucadu.uk".extraConfig = ''
    import common_config
    redir https://www.barrucadu.co.uk{uri}
  '';

  services.caddy.virtualHosts."www.barrucadu.co.uk".extraConfig = ''
    import common_config

    header /fonts/* Cache-Control "public, immutable, max-age=31536000"
    header /*.css   Cache-Control "public, immutable, max-age=31536000"

    file_server {
      root ${httpdir}/barrucadu.co.uk/www
    }

    ${fileContents ./caddy/www-barrucadu-co-uk.caddyfile}
  '';

  services.caddy.virtualHosts."bookdb.barrucadu.co.uk".extraConfig = ''
    import common_config
    reverse_proxy http://127.0.0.1:${toString config.nixfiles.bookdb.port}
  '';

  services.caddy.virtualHosts."bookmarks.barrucadu.co.uk".extraConfig = ''
    import common_config
    reverse_proxy http://127.0.0.1:${toString config.nixfiles.bookmarks.port}
  '';

  services.caddy.virtualHosts."foundry.barrucadu.co.uk".extraConfig = ''
    import common_config
    reverse_proxy http://localhost:${toString config.nixfiles.foundryvtt.port}
  '';

  services.caddy.virtualHosts."memo.barrucadu.co.uk".extraConfig = ''
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
  '';

  services.caddy.virtualHosts."misc.barrucadu.co.uk".extraConfig = ''
    import common_config
    basicauth /_site/* {
      import ${config.sops.secrets."services/caddy/fragments/misc_site".path}
    }

    @subdirectory path_regexp ^/(7day|14day|28day|forever)/[a-z0-9]

    root * ${httpdir}/barrucadu.co.uk/misc
    file_server @subdirectory browse
    file_server
  '';
  sops.secrets."services/caddy/fragments/misc_site".owner = config.users.users.caddy.name;

  services.caddy.virtualHosts."grafana.carcosa.barrucadu.co.uk".extraConfig = ''
    import common_config
    reverse_proxy http://localhost:${toString config.services.grafana.settings.server.http_port}
  '';

  services.caddy.virtualHosts."prometheus.carcosa.barrucadu.co.uk".extraConfig = ''
    import common_config
    reverse_proxy http://localhost:${toString config.services.prometheus.port}
  '';

  services.caddy.virtualHosts."weeknotes.barrucadu.co.uk".extraConfig = ''
    import common_config

    header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
    header /*.css     Cache-Control "public, immutable, max-age=31536000"

    file_server  {
      root ${httpdir}/barrucadu.co.uk/weeknotes
    }
  '';

  services.caddy.virtualHosts."barrucadu.dev".extraConfig = ''
    import common_config
    redir https://www.barrucadu.co.uk
  '';

  services.caddy.virtualHosts."www.barrucadu.dev".extraConfig = ''
    import common_config
    redir https://www.barrucadu.co.uk
  '';

  services.caddy.virtualHosts."cd.barrucadu.dev".extraConfig = ''
    import common_config
    reverse_proxy http://127.0.0.1:${toString config.nixfiles.concourse.port} {
      flush_interval -1
    }
  '';

  services.caddy.virtualHosts."registry.barrucadu.dev".extraConfig = ''
    import common_config
    basicauth /v2/* {
      import ${config.sops.secrets."services/caddy/fragments/registry".path}
    }
    header /v2/* Docker-Distribution-Api-Version "registry/2.0"
    reverse_proxy /v2/* http://127.0.0.1:${toString config.services.dockerRegistry.port}
  '';
  sops.secrets."services/caddy/fragments/registry".owner = config.users.users.caddy.name;

  services.caddy.virtualHosts."lainon.life".extraConfig = ''
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
  '';

  services.caddy.virtualHosts."social.lainon.life".extraConfig = ''
    import common_config
    reverse_proxy http://127.0.0.1:${toString config.nixfiles.pleroma.port}
  '';

  services.caddy.virtualHosts."www.lainon.life".extraConfig = ''
    import common_config
    redir https://lainon.life{uri}
  '';

  services.caddy.virtualHosts."lookwhattheshoggothdraggedin.com".extraConfig = ''
    import common_config
    redir https://www.lookwhattheshoggothdraggedin.com{uri}
  '';

  services.caddy.virtualHosts."www.lookwhattheshoggothdraggedin.com".extraConfig = ''
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
  '';

  services.caddy.virtualHosts."umami.lookwhattheshoggothdraggedin.com".extraConfig = ''
    import common_config
    reverse_proxy http://127.0.0.1:${toString config.nixfiles.umami.port}
  '';

  services.caddy.virtualHosts."uzbl.org".extraConfig = ''
    import common_config
    redir https://www.uzbl.org{uri}
  '';

  services.caddy.virtualHosts."www.uzbl.org".extraConfig = ''
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
    php_fastcgi /atom.xml unix//run/phpfpm/caddy.sock {
      split .xml
    }

    file_server
  '';

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
      "security.limit_extensions" = ".php .xml";
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
  nixfiles.concourse.environmentFile = config.sops.secrets."nixfiles/concourse/env".path;
  nixfiles.concourse.workerScratchDir = "/var/concourse-worker-scratch";
  sops.secrets."nixfiles/concourse/env" = { };

  # Look what the Shoggoth Dragged In
  nixfiles.umami.enable = true;
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

          /run/wrappers/bin/sudo ${pkgs.rsync}/bin/rsync -a --delete ~/bookdb-covers/ ${config.nixfiles.bookdb.dataDir}/covers || exit 1
          /run/wrappers/bin/sudo ${pkgs.coreutils}/bin/chown -R ${config.users.users.bookdb.name}.nogroup ${config.nixfiles.bookdb.dataDir}/covers || exit 1
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
        { command = "${pkgs.coreutils}/bin/chown -R ${config.users.users.bookdb.name}.nogroup ${config.nixfiles.bookdb.dataDir}/covers"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  ###############################################################################
  ## Miscellaneous
  ###############################################################################

  # Metrics
  services.grafana.settings = {
    server.root_url = "https://grafana.carcosa.barrucadu.co.uk";
    security.admin_password = "$__file{${config.sops.secrets."services/grafana/admin_password".path}";
    security.secret_key = "$__file{${config.sops.secrets."services/grafana/secret_key".path}}";
  };
  sops.secrets."services/grafana/admin_password".owner = config.users.users.grafana.name;
  sops.secrets."services/grafana/secret_key".owner = config.users.users.grafana.name;

  services.prometheus.webExternalUrl = "https://prometheus.carcosa.barrucadu.co.uk";

  # Concourse access
  users.extraUsers.concourse-deploy-robot = {
    home = "/var/lib/concourse-deploy-robot";
    createHome = true;
    isSystemUser = true;
    openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFilTWek5xNpl82V48oQ99briJhn9BqwCACeRq1dQnZn concourse-worker@cd.barrucadu.dev" ];
    shell = pkgs.bashInteractive;
    group = "nogroup";
  };

  # Extra packages
  users.extraUsers.barrucadu.packages = with pkgs; [
    irssi
    perl
  ];
}
