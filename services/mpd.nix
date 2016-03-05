{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ mpc_cli mpd ncmpcpp ];

  # User service - copied from the unit file in Arch.
  systemd.user.services.mpd = {
    enable = true;
    description = "Music Player Daemon";
    after = [ "network.target" "sound.target" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart   = "${pkgs.mpd}/bin/mpd --no-daemon";
      LimitRTPRIO = "50";
      LimitRTTIME = "infinity";
    };
  };
}
