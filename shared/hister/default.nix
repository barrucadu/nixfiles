# [hister][] is a locally hosted search engine, with a browser plugin to make it
# easy to index things as you find them.
#
# **Backups:** contents of the `dataDir`.
#
# **Erase your darlings:** overrides the `dataDir`.
#
# [hister]: https://hister.org/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.hister;

  oidc_config = {
    client_id = cfg.oidc.clientId;
    configuration_url = "${cfg.oidc.authUrl}/.well-known/openid-configuration";
  };
in
{
  imports = [
    ./erase-your-darlings.nix
    ./options.nix
  ];

  config = mkIf cfg.enable {
    services.hister = {
      enable = true;
      port = cfg.port;
      group = "nogroup";
      environmentFile = cfg.environmentFile;
      settings = {
        app = {
          directory = config.users.users.hister.home;
          public = true;
          redirect_on_no_results = false;
          user_handling = true;
        };
        server = {
          base_url = "http${optionalString cfg.https "s"}://${cfg.domain}";
          oauth_only = cfg.oidc.enable;
          oauth.oidc = if cfg.oidc.enable then oidc_config else { };
        };
      };
    };
    systemd.services.hister.serviceConfig.ReadWritePaths = config.users.users.hister.home;

    users.users.hister = {
      uid = 983;
      group = "nogroup";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
    };

    nixfiles.restic-backups.backups.hister = {
      prepareCommand = ''
        /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl stop hister
      '';
      cleanupCommand = ''
        /run/wrappers/bin/sudo ${pkgs.systemd}/bin/systemctl start hister
      '';
      paths = [
        config.users.users.hister.home
      ];
    };
    nixfiles.restic-backups.sudoRules = [
      { command = "${pkgs.systemd}/bin/systemctl stop hister"; }
      { command = "${pkgs.systemd}/bin/systemctl start hister"; }
    ];
  };
}
