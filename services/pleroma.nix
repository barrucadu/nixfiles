{ config, lib, pkgs, ...}:

with lib;

let
  cfg = config.services.pleroma;
in
{
  options.services.pleroma = {
    enable = mkOption { type = types.bool; default = false; };
    port   = mkOption { type = types.int; default = 4000; };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ elixir erlang ];

    systemd.services.pleroma = {
      after         = [ "network.target" "postgresql.service" ];
      description   = "Pleroma social network";
      wantedBy      = [ "multi-user.target" ];
      path          = with pkgs; [ elixir git openssl ];
      environment   = {
        HOME    = config.users.extraUsers.pleroma.home;
        MIX_ENV = "prod";
      };
      serviceConfig = {
        WorkingDirectory = "${config.users.extraUsers.pleroma.home}/pleroma";
        User       = "pleroma";
        ExecStart  = "${pkgs.elixir}/bin/mix phx.server";
        ExecReload = "${pkgs.coreutils}/bin/kill $MAINPID";
        KillMode   = "process";
        Restart    = "on-failure";
      };
    };

    services.postgresql.enable = true;
    services.postgresql.package = pkgs.postgresql96;

    users.extraUsers.pleroma = {
      home = "/srv/pleroma";
      createHome = true;
      isSystemUser = true;
    };
  };
}
