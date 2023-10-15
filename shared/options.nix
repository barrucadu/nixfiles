{ lib, ... }:

with lib;

{
  options.nixfiles.firewall = {
    ipBlocklistFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        File containing IPs to block.
      '';
    };
  };
}
