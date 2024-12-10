# Configures a webserver for the following domains:
#
# - {www,bookdb,bookmarks,memos,weeknotes,}barrucadu.co.uk
# - {www,}barrucadu.com
# - {www,}barrucadu.dev
# - {www,}barrucadu.uk
#
# The state of each website (static files, databases) needs to be synchronised
# to this machine for the sites to work.
{ config, lib, pkgs, ... }:

with lib;
let
  httpDir =
    if config.nixfiles.eraseYourDarlings.enable
    then "${toString config.nixfiles.eraseYourDarlings.persistDir}/srv/http"
    else "/srv/http";

  certDirFor = domain:
    if config.nixfiles.eraseYourDarlings.enable
    then "${toString config.nixfiles.eraseYourDarlings.persistDir}/var/lib/acme/${domain}"
    else "/var/lib/acme/${domain}";

  copyCertsFor = domain: ''
    mkdir -p ${toString config.nixfiles.eraseYourDarlings.persistDir}/var/lib/acme || true
    rm -r ${toString config.nixfiles.eraseYourDarlings.persistDir}/var/lib/acme/${domain} || true
    cp -a /var/lib/acme/${domain} ${toString config.nixfiles.eraseYourDarlings.persistDir}/var/lib/acme/${domain}
  '';

  caddyConfigWithTlsCert = certDomain: ''
    encode gzip

    header Permissions-Policy "interest-cohort=()"
    header Referrer-Policy "strict-origin-when-cross-origin"
    header Strict-Transport-Security "max-age=31536000; includeSubDomains"
    header X-Content-Type-Options "nosniff"
    header X-Frame-Options "SAMEORIGIN"

    header -Server

    tls ${certDirFor certDomain}/cert.pem ${certDirFor certDomain}/key.pem {
      protocols tls1.3
    }
  '';
in
{
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
      environmentFile = config.sops.secrets."services/acme/env".path;
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
  sops.secrets."services/acme/env" = { };


  ###############################################################################
  ## HTTP
  ###############################################################################

  # http
  services.caddy.enable = true;

  # redirects
  services.caddy.virtualHosts."barrucadu.co.uk".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.co.uk"}

    redir https://www.barrucadu.co.uk{uri}
  '';

  services.caddy.virtualHosts."barrucadu.com".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.com"}

    redir https://www.barrucadu.co.uk{uri}
  '';

  services.caddy.virtualHosts."www.barrucadu.com".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.com"}

    redir https://www.barrucadu.co.uk{uri}
  '';

  services.caddy.virtualHosts."barrucadu.dev".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.dev"}

    redir https://www.barrucadu.co.uk
  '';

  services.caddy.virtualHosts."www.barrucadu.dev".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.dev"}

    redir https://www.barrucadu.co.uk
  '';

  services.caddy.virtualHosts."barrucadu.uk".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.uk"}

    redir https://www.barrucadu.co.uk{uri}
  '';

  services.caddy.virtualHosts."www.barrucadu.uk".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.uk"}

    redir https://www.barrucadu.co.uk{uri}
  '';

  # real sites
  services.caddy.virtualHosts."www.barrucadu.co.uk".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.co.uk"}

    header /fonts/* Cache-Control "public, immutable, max-age=31536000"
    header /*.css   Cache-Control "public, immutable, max-age=31536000"

    file_server {
      root ${httpDir}/barrucadu.co.uk/www
    }

    ${fileContents ./barrucadu-website-mirror/www-barrucadu-co-uk.caddyfile}
  '';

  services.caddy.virtualHosts."bookdb.barrucadu.co.uk".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.co.uk"}

    reverse_proxy http://127.0.0.1:${toString config.nixfiles.bookdb.port}
  '';

  services.caddy.virtualHosts."bookmarks.barrucadu.co.uk".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.co.uk"}

    reverse_proxy http://127.0.0.1:${toString config.nixfiles.bookmarks.port}
  '';

  services.caddy.virtualHosts."memo.barrucadu.co.uk".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.co.uk"}

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

    ${fileContents ./barrucadu-website-mirror/memo-barrucadu-co-uk.caddyfile}
  '';

  services.caddy.virtualHosts."weeknotes.barrucadu.co.uk".extraConfig = ''
    ${caddyConfigWithTlsCert "barrucadu.co.uk"}

    header /fonts/*   Cache-Control "public, immutable, max-age=31536000"
    header /*.css     Cache-Control "public, immutable, max-age=31536000"

    file_server  {
      root ${httpDir}/barrucadu.co.uk/weeknotes
    }
  '';


  ###############################################################################
  ## Miscellaneous
  ###############################################################################

  # bookdb
  nixfiles.bookdb.enable = true;
  nixfiles.bookdb.readOnly = true;

  # bookmarks
  nixfiles.bookmarks.enable = true;
  nixfiles.bookmarks.readOnly = true;

  # Firewall
  networking.firewall.allowedTCPPorts = [ 80 443 ];

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
}
