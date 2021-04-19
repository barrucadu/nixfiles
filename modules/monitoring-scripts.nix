{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.monitoringScripts;
in
{
  options = {
    modules = {
      monitoringScripts = {
        enable = mkOption { type = types.bool; default = true; };
        onCalendar = mkOption { type = types.str; default = "monthly"; };
        scriptDirectory = mkOption { type = types.path; default = "/home/barrucadu/monitoring-scripts"; };
        scriptUser = mkOption { type = types.str; default = "barrucadu"; };
        scriptGroup = mkOption { type = types.str; default = "users"; };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.timers.monitoring-scripts = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
      };
    };

    systemd.services.monitoring-scripts = {
      description = "Run monitoring scripts";
      serviceConfig.WorkingDirectory = cfg.scriptDirectory;
      serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ./monitor.sh";
      serviceConfig.User = cfg.scriptUser;
      serviceConfig.Group = cfg.scriptGroup;
    };
  };
}
