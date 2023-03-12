{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.pleroma;
  eyd = config.nixfiles.eraseYourDarlings;

  # systemd unit assumes files are accessible under "/var/lib/pleroma"
  pleromaHome = "${toString eyd.persistDir}/var/lib/pleroma";
in
{
  config = mkIf (cfg.enable && eyd.enable) {
    users.users.pleroma.home = mkForce pleromaHome;
    systemd.services.pleroma.serviceConfig.BindPaths = [ "${pleromaHome}:/var/lib/pleroma" ];
  };
}
