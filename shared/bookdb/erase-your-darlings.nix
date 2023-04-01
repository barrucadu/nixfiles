{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.bookdb;
  eyd = config.nixfiles.eraseYourDarlings;
in
{
  config = mkIf (cfg.enable && eyd.enable) {
    nixfiles.bookdb.dataDir = "${toString eyd.persistDir}/srv/bookdb";
  };
}
