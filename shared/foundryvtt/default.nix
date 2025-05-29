# [FoundryVTT][] is a virtual tabletop to run roleplaying games.  It is licensed
# software and needs to be downloaded after purchase.  This module doesn't
# manage the FoundryVTT program files, only operating it.
#
# The downloaded FoundryVTT program files must be in `''${dataDir}/bin`.
#
# **Backups:** the data files - this requires briefly stopping the service, so
# don't schedule backups during game time.
#
# **Erase your darlings:** overrides the `dataDir`.
#
# [FoundryVTT]: https://foundryvtt.com/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.foundryvtt;
in
{
  imports = [
    ./erase-your-darlings.nix
    ./options.nix
  ];

  config = mkIf cfg.enable {
    systemd.services.foundryvtt = {
      enable = true;
      description = "Foundry Virtual Tabletop";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.nodejs_24}/bin/node resources/app/main.js --dataPath=${cfg.dataDir}/data --port=${toString cfg.port}";
        Restart = "always";
        User = "foundryvtt";
        WorkingDirectory = "${cfg.dataDir}/bin";
      };
    };

    users.users.foundryvtt = {
      uid = 994;
      description = "Foundry VTT service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "nogroup";
    };

    nixfiles.restic-backups.backups.foundryvtt = {
      prepareCommand = ''
        /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl stop foundryvtt
      '';
      cleanupCommand = ''
        /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl start foundryvtt
      '';
      paths = [
        cfg.dataDir
      ];
    };
    nixfiles.restic-backups.sudoRules = [
      { command = "${pkgs.systemd}/bin/systemctl stop foundryvtt"; }
      { command = "${pkgs.systemd}/bin/systemctl start foundryvtt"; }
    ];
  };
}
