{ lib, ... }:

with lib;

{
  options.nixfiles.bookdb = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 46667; };
    esPort = mkOption { type = types.int; default = 47164; };
    esTag = mkOption { type = types.str; default = "8.0.0"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    dataDir = mkOption { type = types.str; default = "/srv/bookdb"; };
  };
}
