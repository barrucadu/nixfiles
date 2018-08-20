{ config, pkgs, lib, ... }:

{
  options = {
    services.monitoring-scripts.OnCalendar = lib.mkOption {
        default = "0/12:00:00";
        description = "When to run the monitoring service";
      };
  };

  config = {
    systemd.timers.monitoring-scripts = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = config.services.monitoring-scripts.OnCalendar;
      };
    };
    systemd.services.monitoring-scripts = {
      description = "Run monitoring scripts";
      serviceConfig.WorkingDirectory = "/home/barrucadu/monitoring-scripts";
      serviceConfig.ExecStart = "${pkgs.zsh}/bin/zsh --login -c ./monitor.sh";
      serviceConfig.User = "barrucadu";
      serviceConfig.Group = "users";
    };
  };
}
