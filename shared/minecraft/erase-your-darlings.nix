{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.minecraft;
  eyd = config.nixfiles.eraseYourDarlings;
in
{
  config = mkIf (cfg.enable && eyd.enable) {
    nixfiles.minecraft.dataDir = "${toString eyd.persistDir}/srv/minecraft";
  };
}
