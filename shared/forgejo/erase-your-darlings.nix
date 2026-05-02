{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.forgejo;
  eyd = config.nixfiles.eraseYourDarlings;
in
{
  config = mkIf (cfg.enable && eyd.enable) {
    services.forgejo.stateDir = "${toString eyd.persistDir}/var/lib/forgejo";
  };
}
