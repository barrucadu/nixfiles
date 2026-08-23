{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.hister;
  eyd = config.nixfiles.eraseYourDarlings;
in
{
  config = mkIf (cfg.enable && eyd.enable) {
    nixfiles.hister.dataDir = "${toString eyd.persistDir}/var/lib/hister";
  };
}
