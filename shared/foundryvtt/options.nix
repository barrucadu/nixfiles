{ lib, ... }:

with lib;

{
  options.nixfiles.foundryvtt = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 46885; };
    dataDir = mkOption { type = types.str; default = "/var/lib/foundryvtt"; };
  };
}
