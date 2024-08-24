{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.torrents;
  eyd = config.nixfiles.eraseYourDarlings;
in
{
  config = mkIf (cfg.enable && eyd.enable) {
    nixfiles.torrents.stateDir = "${toString eyd.persistDir}/var/lib/torrents";
  };
}
