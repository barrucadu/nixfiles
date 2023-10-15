{ lib, ... }:

with lib;

{
  options.nixfiles.bookmarks = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 48372; };
    esPort = mkOption { type = types.int; default = 43389; };
    esTag = mkOption { type = types.str; default = "8.0.0"; };
    baseURI = mkOption { type = types.str; };
    readOnly = mkOption { type = types.bool; default = false; };
    environmentFile = mkOption { type = types.nullOr types.str; default = null; };
  };
}
