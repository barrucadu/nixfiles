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
  imports = [
    ../_templates/barrucadu-website-mirror.nix
  ];

  ###############################################################################
  ## General
  ###############################################################################

  networking.hostId = "f62895cc";
  boot.supportedFilesystems = { zfs = true; };

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

  nixfiles.restic-backups.enable = true;
  nixfiles.restic-backups.environmentFile = config.sops.secrets."nixfiles/restic-backups/env".path;
  nixfiles.restic-backups.checkRepositoryAt = "Wed, 12:00";
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

  # WWW - there are more websites, see barrucadu-website-mirror
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

  services.caddy.virtualHosts."foundry.barrucadu.co.uk".extraConfig = ''
    import common_config
    reverse_proxy http://localhost:${toString config.nixfiles.foundryvtt.port}
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

  services.caddy.virtualHosts."carcosa.barrucadu.co.uk".extraConfig = ''
    import common_config
    redir https://www.barrucadu.co.uk
  '';

  services.caddy.virtualHosts."grafana.carcosa.barrucadu.co.uk".extraConfig = ''
    import common_config
    reverse_proxy http://localhost:${toString config.services.grafana.settings.server.http_port}
  '';

  services.caddy.virtualHosts."prometheus.carcosa.barrucadu.co.uk".extraConfig = ''
    import common_config
    reverse_proxy http://localhost:${toString config.services.prometheus.port}
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
      @410 {
        expression {http.error.status_code} == 410
      }
      rewrite @404 /404.html
      rewrite @410 /404.html
      file_server
    }

    ${fileContents ./caddy/www-lookwhattheshoggothdraggedin-com.caddyfile}
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

  nixfiles.bookdb.remoteSync.receive.enable = true;
  nixfiles.bookdb.remoteSync.receive.authorizedKeys =
    [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChVw9DPLafA3lCLCI4Df9rYuxedFQTXAwDOOHUfZ0Ac remote-sync@nyarlathotep" ];

  nixfiles.bookmarks.remoteSync.receive.enable = true;
  nixfiles.bookmarks.remoteSync.receive.authorizedKeys =
    [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIChVw9DPLafA3lCLCI4Df9rYuxedFQTXAwDOOHUfZ0Ac remote-sync@nyarlathotep" ];


  ###############################################################################
  ## Remote Builds
  ###############################################################################

  users.extraUsers.nix-remote-builder = {
    home = "/var/lib/nix-remote-builder";
    createHome = true;
    isSystemUser = true;
    shell = pkgs.bashInteractive;
    group = "nogroup";
    openssh.authorizedKeys.keys =
      [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHFzMpx7QNSAb5tCbkzMRIG62PvBZysflwwCKchFDHtY nix@yuggoth" ];
  };
  nix.settings.trusted-users = [ config.users.extraUsers.nix-remote-builder.name ];


  ###############################################################################
  ## Miscellaneous
  ###############################################################################

  # Metrics
  services.grafana.settings = {
    server.root_url = "https://grafana.carcosa.barrucadu.co.uk";
    security.admin_password = "$__file{${config.sops.secrets."services/grafana/admin_password".path}}";
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
