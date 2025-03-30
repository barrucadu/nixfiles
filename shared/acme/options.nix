{ lib, ... }:

with lib;

{
  options.nixfiles.acme = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the ACME DNS-01 service.
      '';
    };

    environmentFile = mkOption {
      type = types.path;
      description = ''
        Environment file with AWS Route53 credentials for the ACME DNS-01 challenge.
      '';
    };

    domains = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          extraDomainNames = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              Extra domain names under this certificate.
            '';
          };
        };
      });
      description = ''
        Attrset of domain / certificate definitions.
      '';
    };
  };
}
