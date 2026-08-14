{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.vikunja;
  eyd = config.nixfiles.eraseYourDarlings;
in
{
  config = mkIf (cfg.enable && eyd.enable) {
    nixfiles.vikunja.dataDir = "${toString eyd.persistDir}/var/lib/vikunja";
  };
}
