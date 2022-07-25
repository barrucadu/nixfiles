{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.modules.monitoringScripts;

  runScript = cmd: name: source: ''
    echo "${name}"
    if ! time ${cmd} "${pkgs.writeText "${name}.monitoring-script" source}" > $OUTFILE; then
      echo "Failure:"
      cat $OUTFILE
      aws sns publish --topic-arn "$TOPIC_ARN" --subject "Alert: ${config.networking.hostName}" --message "file://''${OUTFILE}"
    fi
  '';
in
{
  options = {
    modules = {
      monitoringScripts = {
        enable = mkOption { type = types.bool; default = false; };
        scripts = mkOption { type = types.attrsOf types.str; default = { }; };
        environmentFile = mkOption { type = types.str; };
        onCalendar = mkOption { type = types.str; default = "hourly"; };
        user = mkOption { type = types.str; default = "barrucadu"; };
        group = mkOption { type = types.str; default = "users"; };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.timers.monitoring-scripts = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = cfg.onCalendar;
    };

    systemd.services.monitoring-scripts = {
      description = "Run monitoring scripts";
      path = with pkgs; [ awscli bash zfs ];
      serviceConfig = {
        ExecStart = pkgs.writeShellScript "monitoring.sh" ''
          set -e

          OUTFILE=`mktemp`
          trap "rm $OUTFILE" EXIT

          ${concatStringsSep "\n" (mapAttrsToList (runScript "bash -e -o pipefail") cfg.scripts)}
        '';
        EnvironmentFile = cfg.environmentFile;
        User = cfg.user;
        Group = cfg.group;
      };
    };
  };
}
