{ lib, ... }:

with lib;

{
  options.nixfiles.rtorrent = {
    enable = mkOption { type = types.bool; default = false; };
    downloadDir = mkOption { type = types.str; };
    watchDir = mkOption { type = types.str; };
    user = mkOption { type = types.str; };
    logLevels = mkOption { type = types.listOf types.str; default = [ "info" ]; };
    openFirewall = mkOption { type = types.bool; default = true; };
    portRange = {
      from = mkOption { type = types.int; default = 50000; };
      to = mkOption { type = types.int; default = 50000; };
    };
    flood = {
      enable = mkOption { type = types.bool; default = true; };
      port = mkOption { type = types.int; default = 45904; };
    };
  };
}
