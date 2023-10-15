{ lib, ... }:

with lib;

{
  options.nixfiles.umami = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 46489; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    umamiTag = mkOption { type = types.str; default = "postgresql-latest"; };
    environmentFile = mkOption { type = types.str; };
  };
}
