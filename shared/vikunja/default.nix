# [vikjuna][] is a project management tool.
#
# The `environmentFile` must contain the following env vars:
#
#   - `VIKUNJA_SERVICE_SECRET`
#
# **Backups:** the data directory.
#
# **Erase your darlings:** transparently stores data on the persistent volume.
#
# [vikunja]: https://vikunja.io/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.vikunja;

  settings = {
    database = {
      type = "sqlite";
      path = "${cfg.dataDir}/vikunja.db";
    };
    service = {
      interface = "127.0.0.1:${toString cfg.port}";
      publicurl = "http${optionalString cfg.urlsAreHTTPS "s"}://${cfg.domain}";
    };
    files = {
      basepath = "${cfg.dataDir}/files";
    };
  };

  configFile = (pkgs.formats.yaml { }).generate "config.yaml" settings;
in
{
  imports = [
    ./erase-your-darlings.nix
    ./options.nix
  ];

  config = mkIf cfg.enable {
    systemd.services.vikunja = {
      description = "vikunja";
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [ configFile ];
      serviceConfig = {
        ExecStart = "${pkgs.vikunja}/bin/vikunja";
        Restart = "always";
        EnvironmentFiles = [ cfg.environmentFile ];
        User = config.users.users.vikunja.name;
      };
    };

    environment.etc."vikunja/config.yaml".source = configFile;

    users.users.vikunja = {
      uid = 990;
      description = "vikunja service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "nogroup";
    };

    nixfiles.restic-backups.backups.vikunja = {
      prepareCommand = ''
        /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl stop vikunja
      '';
      cleanupCommand = ''
        /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl start vikunja
      '';
      paths = [
        cfg.dataDir
      ];
    };
    nixfiles.restic-backups.sudoRules = [
      { command = "${pkgs.systemd}/bin/systemctl stop vikunja"; }
      { command = "${pkgs.systemd}/bin/systemctl start vikunja"; }
    ];
  };
}
