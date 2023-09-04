{ config, lib, ... }:

with lib;
let
  cfg = config.nixfiles.rtorrent;
  eyd = config.nixfiles.eraseYourDarlings;

  logDir = "/var/log/rtorrent";
  stateDir = "/var/lib/rtorrent";
in
{
  config = mkIf (cfg.enable && eyd.enable) {
    systemd.services.rtorrent.serviceConfig.BindPaths = [
      "${toString eyd.persistDir}${logDir}:${logDir}"
      "${toString eyd.persistDir}${stateDir}/session:${stateDir}/session"
    ];
    systemd.services.flood.serviceConfig.BindPaths = [
      "${toString eyd.persistDir}${stateDir}/flood:${stateDir}/flood"
    ];
  };
}
