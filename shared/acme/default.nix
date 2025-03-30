# Manage ACME (LetsEncrypt) certificates via Route53 DNS challenge.
#
# **Erase your darlings:** stores certificates in `persistDir`.
{ config, lib, pkgs, ... }:

with lib;
let
  baseDir =
    if config.nixfiles.eraseYourDarlings.enable
    then toString config.nixfiles.eraseYourDarlings.persistDir
    else "";

  certDir = "${baseDir}/var/lib/acme";

  copyCertsFor = domain: ''
    mkdir -p ${certDir} || true
    rm -r ${certDir}/${domain} || true
    cp -a /var/lib/acme/${domain} ${certDir}/${domain}
  '';

  mkCert = domain: cfg: nameValuePair domain {
    inherit domain;
    inherit (cfg) extraDomainNames;
    group = config.services.caddy.group;
    postRun = if config.nixfiles.eraseYourDarlings.enable then copyCertsFor domain else "";
  };

  cfg = config.nixfiles.acme;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    security.acme = {
      acceptTerms = true;

      defaults = {
        email = "mike@barrucadu.co.uk";
        dnsProvider = "route53";
        dnsPropagationCheck = true;
        environmentFile = cfg.environmentFile;
        reloadServices = [ "caddy" ];
      };

      certs = mapAttrs' mkCert cfg.domains;
    };

    users.users.acme.uid = 986;
    users.groups.acme.gid = 989;
  };
}
