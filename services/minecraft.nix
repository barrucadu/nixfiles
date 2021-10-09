{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.minecraft;
in
{
  # yes I know there's a NixOS minecraft module but it uses the
  # Minecraft in nixpkgs whereas I want to run modded servers and
  # packaging one is a pain.
  options.services.minecraft = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 25565; };
    dataDir = mkOption { type = types.path; default = "/srv/minecraft"; };
    jar = mkOption { type = types.str; default = "fabric-server-launch.jar"; };
    jvmOpts = mkOption { type = types.separatedString " "; default = "-Xmx4096M -Xms4096M"; };
  };

  config = mkIf cfg.enable {
    # from https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/games/minecraft-server.nix
    users.users.minecraft = {
      description = "Minecraft server service user";
      home = cfg.dataDir;
      createHome = true;
      uid = config.ids.uids.minecraft;
    };

    systemd.sockets.minecraft-stdin = {
      description = "stdin for Minecraft Server";
      socketConfig = {
        ListenFIFO = "%t/minecraft.stdin";
        Service = "minecraft.service";
      };
    };
    systemd.services.minecraft = {
      description = "Minecraft Server Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = "${pkgs.jre8_headless}/bin/java ${cfg.jvmOpts} -jar ${cfg.jar}";
        Restart = "always";
        User = "minecraft";
        WorkingDirectory = cfg.dataDir;
        Sockets = "minecraft-stdin.socket";
        StandardInput = "socket";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    networking.firewall.allowedUDPPorts = [ cfg.port ];
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
