{ lib, ... }:

with lib;

{
  options.nixfiles.firewall = {
    ipBlocklistFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        File containing IPs to block.  This is of the form:

        ```text
        ip-address # comment
        ip-address # comment
        ...
        ```
      '';
    };
  };
}
