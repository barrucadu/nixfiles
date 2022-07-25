# FoundryVTT is licensed software and needs to be downloaded after
# purchase.

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.foundryvtt;
in
{
  options.services.foundryvtt = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 3000; };
    dataDir = mkOption { type = types.str; default = "/srv/foundry"; };
  };

  config = mkIf cfg.enable {
    systemd.services.foundryvtt = {
      enable = true;
      description = "Foundry Virtual Tabletop";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.nodejs-18_x}/bin/node resources/app/main.js --dataPath=${cfg.dataDir}/data --port=${toString cfg.port}";
        Restart = "always";
        User = "foundryvtt";
        WorkingDirectory = "${cfg.dataDir}/bin";
      };
    };

    users.users.foundryvtt = {
      description = "Foundry VTT service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "nogroup";
    };

    # TODO: figure out how to get `sudo` in the unit's path (adding the
    # package doesn't help - need the wrapper)
    modules.backupScripts.scripts.foundryvtt = ''
      /run/wrappers/bin/sudo systemctl stop foundryvtt
      /run/wrappers/bin/sudo tar cfz dump.tar.gz ${cfg.dataDir}
      /run/wrappers/bin/sudo chown ${config.modules.backupScripts.user}.${config.modules.backupScripts.group} dump.tar.gz
      /run/wrappers/bin/sudo systemctl start foundryvtt
    '';
    security.sudo.extraRules = [
      {
        users = [ config.modules.backupScripts.user ];
        commands = [
          { command = "${pkgs.systemd}/bin/systemctl stop foundryvtt"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.systemd}/bin/systemctl start foundryvtt"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.gnutar}/bin/tar cfz dump.tar.gz ${cfg.dataDir}"; options = [ "NOPASSWD" ]; }
          { command = "${pkgs.coreutils}/bin/chown ${config.modules.backupScripts.user}.${config.modules.backupScripts.group} dump.tar.gz"; options = [ "NOPASSWD" ]; }
        ];
      }
    ];
  };
}
