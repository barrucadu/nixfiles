# Configures a webserver for the following domains:
#
# - {www,bookdb,bookmarks,memos,weeknotes,}barrucadu.co.uk
# - {www,}barrucadu.com
# - {www,}barrucadu.dev
# - {www,}barrucadu.uk
#
# Access is configured for push-based updates:
#
# - Remote sync (defaulting to the nyarlathotep SSH key) for bookdb and bookmarks
# - SSH and file ownership (defaulting to the concourse SSH key) for static websites
#
# Push needs to be configured in the appropriate places.
{ config, lib, pkgs, ... }:

with lib;
let
  baseDir =
    if config.nixfiles.eraseYourDarlings.enable
    then toString config.nixfiles.eraseYourDarlings.persistDir
    else "";

  httpDir = "${baseDir}/srv/http";
  certDir = "${baseDir}/var/lib/acme";

  copyCertsFor = domain: ''
    mkdir -p ${toString config.nixfiles.eraseYourDarlings.persistDir}/var/lib/acme || true
    rm -r ${toString config.nixfiles.eraseYourDarlings.persistDir}/var/lib/acme/${domain} || true
    cp -a /var/lib/acme/${domain} ${toString config.nixfiles.eraseYourDarlings.persistDir}/var/lib/acme/${domain}
  '';

  caddyTlsConfig = certDomain: ''
    tls ${certDir}/${certDomain}/cert.pem ${certDir}/${certDomain}/key.pem {
      protocols tls1.3
    }
  '';

  caddyConfig = ''
    encode gzip

    header Permissions-Policy "interest-cohort=()"
    header Referrer-Policy "strict-origin-when-cross-origin"
    header Strict-Transport-Security "max-age=31536000; includeSubDomains"
    header X-Content-Type-Options "nosniff"
    header X-Frame-Options "SAMEORIGIN"

    header -Server
  '';

  cfg = config.nixfiles.hostTemplates.websiteMirror;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    ###############################################################################
    ## Certificates
    ###############################################################################

    # Provision certificates via DNS challenge
    security.acme = {
      acceptTerms = true;

      defaults = {
        email = "mike@barrucadu.co.uk";
        dnsProvider = "route53";
        dnsPropagationCheck = true;
        environmentFile = cfg.acmeEnvironmentFile;
        reloadServices = [ "caddy" ];
      };

      certs."barrucadu.co.uk" = {
        group = config.services.caddy.group;
        domain = "barrucadu.co.uk";
        extraDomainNames = [ "*.barrucadu.co.uk" ];
        postRun = if config.nixfiles.eraseYourDarlings.enable then copyCertsFor "barrucadu.co.uk" else "";
      };

      certs."barrucadu.com" = {
        group = config.services.caddy.group;
        domain = "barrucadu.com";
        extraDomainNames = [ "*.barrucadu.com" ];
        postRun = if config.nixfiles.eraseYourDarlings.enable then copyCertsFor "barrucadu.com" else "";
      };

      certs."barrucadu.dev" = {
        group = config.services.caddy.group;
        domain = "barrucadu.dev";
        extraDomainNames = [ "*.barrucadu.dev" ];
        postRun = if config.nixfiles.eraseYourDarlings.enable then copyCertsFor "barrucadu.dev" else "";
      };

      certs."barrucadu.uk" = {
        group = config.services.caddy.group;
        domain = "barrucadu.uk";
        extraDomainNames = [ "*.barrucadu.uk" ];
        postRun = if config.nixfiles.eraseYourDarlings.enable then copyCertsFor "barrucadu.uk" else "";
      };
    };

    users.users.acme.uid = 986;
    users.groups.acme.gid = 989;


    ###############################################################################
    ## Websites
    ###############################################################################

    services.caddy.enable = true;

    services.caddy.virtualHosts =
      let
        vhosts = {
          "barrucadu.co.uk" = {
            "" = ''
              redir https://www.barrucadu.co.uk{uri}
            '';
            "bookdb" = ''
              reverse_proxy http://127.0.0.1:${toString config.nixfiles.bookdb.port}
            '';
            "bookmarks" = ''
              reverse_proxy http://127.0.0.1:${toString config.nixfiles.bookmarks.port}
            '';
            "memo" = ''
              header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
              header /mathjax/* Cache-Control "public, immutable, max-age=7776000"
              header /*.css     Cache-Control "public, immutable, max-age=31536000"

              root * ${httpDir}/barrucadu.co.uk/memo
              file_server

              handle_errors {
                @410 {
                  expression {http.error.status_code} == 410
                }
                rewrite @410 /410.html
                file_server
              }

              ${fileContents ./resources/memo-barrucadu-co-uk.caddyfile}
            '';
            "weeknotes" = ''
              header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
              header /*.css     Cache-Control "public, immutable, max-age=31536000"

              file_server  {
                root ${httpDir}/barrucadu.co.uk/weeknotes
              }
            '';
            "www" = ''
              header /fonts/* Cache-Control "public, immutable, max-age=31536000"
              header /*.css   Cache-Control "public, immutable, max-age=31536000"

              root * ${httpDir}/barrucadu.co.uk/www
              file_server

              handle_errors {
                @404 {
                  expression {http.error.status_code} == 404
                }
                @410 {
                  expression {http.error.status_code} == 410
                }
                rewrite @404 /404.html
                rewrite @410 /410.html
                file_server
              }

              ${fileContents ./resources/www-barrucadu-co-uk.caddyfile}
            '';
          };
          "barrucadu.com" = {
            "" = ''
              redir https://www.barrucadu.co.uk
            '';
            "www" = ''
              redir https://www.barrucadu.co.uk
            '';
          };
          "barrucadu.uk" = {
            "" = ''
              redir https://www.barrucadu.co.uk
            '';
            "www" = ''
              redir https://www.barrucadu.co.uk
            '';
          };
          "barrucadu.dev" = {
            "" = ''
              redir https://www.barrucadu.co.uk
            '';
            "www" = ''
              redir https://www.barrucadu.co.uk
            '';
          };
        };
        mkVirtualHost = withTlsConfig: domain: subdomain: extraConfig: nameValuePair (if subdomain == "" then domain else "${subdomain}.${domain}") {
          extraConfig = ''
            ${caddyConfig}
            ${optionalString withTlsConfig (caddyTlsConfig domain)}
            ${extraConfig}
          '';
        };
        mkVirtualHosts = domain: subdomains: mapAttrs' (mkVirtualHost true domain) subdomains;
        mkPrefixedVirtualHosts = domain: subdomains: mapAttrs' (mkVirtualHost false "${config.networking.hostName}.${domain}") (filterAttrs (n: _: n != "") subdomains);
      in
      mkMerge [
        (concatMapAttrs mkVirtualHosts vhosts)
        (concatMapAttrs mkPrefixedVirtualHosts vhosts)
      ];


    ###############################################################################
    ## Services
    ###############################################################################

    nixfiles.bookdb.enable = true;
    nixfiles.bookdb.readOnly = true;

    nixfiles.bookmarks.enable = true;
    nixfiles.bookmarks.readOnly = true;

    nixfiles.bookdb.remoteSync.receive.enable = config.nixfiles.bookdb.enable;
    nixfiles.bookdb.remoteSync.receive.authorizedKeys = cfg.bookdbRemoteSyncAuthorizedKeys;

    nixfiles.bookmarks.remoteSync.receive.enable = config.nixfiles.bookmarks.enable;
    nixfiles.bookmarks.remoteSync.receive.authorizedKeys = cfg.bookmarksRemoteSyncAuthorizedKeys;


    ###############################################################################
    ## Miscellaneous
    ###############################################################################

    # Firewall
    networking.firewall.allowedTCPPorts = [ 80 443 ];

    # Concourse access
    users.users.concourse-deploy-robot = {
      uid = 997;
      home = "/var/lib/concourse-deploy-robot";
      createHome = true;
      isSystemUser = true;
      openssh.authorizedKeys.keys = cfg.concourseDeployRobotAuthorizedKeys;
      shell = pkgs.bashInteractive;
      group = "nogroup";
    };

    # Create needed directories if they don't already exist
    systemd.tmpfiles.rules = [
      # acme & caddy services
      "d ${certDir} - root root -"
      "d ${baseDir}/var/lib/caddy 700 caddy caddy -"
      # static websites (for rsync - seems to want to traverse from /)
      "d ${baseDir}/srv - root root -"
      "d ${httpDir} - root root -"
      "d ${httpDir}/barrucadu.co.uk - root root -"
      "d ${httpDir}/barrucadu.co.uk/memo - concourse-deploy-robot nogroup -"
      "d ${httpDir}/barrucadu.co.uk/weeknotes - concourse-deploy-robot nogroup -"
      "d ${httpDir}/barrucadu.co.uk/www - concourse-deploy-robot nogroup -"
      # docker volumes
      "d ${config.nixfiles.oci-containers.volumeBaseDir}/bookdb/esdata - 1000 100 -"
      "d ${config.nixfiles.oci-containers.volumeBaseDir}/bookmarks/esdata - 1000 100 -"
    ];
  };
}
