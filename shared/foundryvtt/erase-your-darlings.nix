{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.foundryvtt;
  eyd = config.nixfiles.eraseYourDarlings;
in
{
  config = mkIf (cfg.enable && eyd.enable) {
    nixfiles.foundryvtt.dataDir = "${toString eyd.persistDir}/srv/foundry";
  };
}
