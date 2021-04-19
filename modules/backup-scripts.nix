{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.backupScripts;
in
{
  options = {
    modules = {
      backupScripts = {
        enable = mkOption { type = types.bool; default = true; };
        onCalendarFull = mkOption { type = types.str; default = "monthly"; };
        onCalendarIncr = mkOption { type = types.str; default = "Mon, 04:00"; };
        scriptDirectory = mkOption { type = types.path; default = "/home/barrucadu/backup-scripts"; };
        scriptUser = mkOption { type = types.str; default = "barrucadu"; };
        scriptGroup = mkOption { type = types.str; default = "users"; };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.timers.backup-scripts-full = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendarFull;
      };
    };

    systemd.timers.backup-scripts-incr = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendarIncr;
      };
    };

    systemd.services.backup-scripts-full = {
      description = "Take a full backup";
      serviceConfig.WorkingDirectory = cfg.scriptDirectory;
      serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c './backup.sh full'";
      serviceConfig.User = cfg.scriptUser;
      serviceConfig.Group = cfg.scriptGroup;
    };

    systemd.services.backup-scripts-incr = {
      description = "Take an incremental backup";
      serviceConfig.WorkingDirectory = cfg.scriptDirectory;
      serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c './backup.sh incr'";
      serviceConfig.User = cfg.scriptUser;
      serviceConfig.Group = cfg.scriptGroup;
    };
  };
}
