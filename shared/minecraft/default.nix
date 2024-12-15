# [Minecraft][] Java Edition runner.  Supports multiple servers, with mods.
# This module doesn't manage the Minecraft server files, only operating them.
#
# Yes, I know there's a NixOS minecraft module, but it uses the Minecraft in
# nixpkgs and only runs one server, whereas I want to run multiple modded
# servers.
#
# The Minecraft server files must be in `''${dataDir}/{name}`.
#
# This module does not include a backup script.  Servers must be backed up
# independently.
#
# **Erase your darlings:** overrides the `dataDir`.
#
# [Minecraft]: https://www.minecraft.net/en-us
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.minecraft;

  serverPorts = mapAttrsToList (_: server: server.port) cfg.servers;
in
{
  imports = [
    ./erase-your-darlings.nix
    ./options.nix
  ];

  config = mkIf cfg.enable {
    # from https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/games/minecraft-server.nix
    users.users.minecraft = {
      uid = 993;
      description = "Minecraft server service user";
      home = cfg.dataDir;
      createHome = true;
      isSystemUser = true;
      group = "nogroup";
    };

    systemd.sockets =
      let
        make = name: _: nameValuePair "minecraft-${name}-stdin"
          {
            description = "stdin for minecraft-${name}";
            socketConfig = {
              ListenFIFO = "%t/minecraft-${name}.stdin";
              Service = "minecraft-${name}.service";
            };
          };
      in
      mapAttrs' make cfg.servers;

    systemd.services =
      let
        make = name: server: nameValuePair "minecraft-${name}"
          {
            description = "Minecraft Server Service (${name})";
            wantedBy = if server.autoStart then [ "multi-user.target" ] else [ ];
            after = [ "network.target" ];

            serviceConfig = {
              ExecStart = "${server.jre}/bin/java ${server.jvmOpts} -jar ${server.jar}";
              Restart = "always";
              User = "minecraft";
              WorkingDirectory = "${cfg.dataDir}/${name}";
              Sockets = "minecraft-${name}-stdin.socket";
              StandardInput = "socket";
              StandardOutput = "journal";
              StandardError = "journal";
            };
          };
      in
      mapAttrs' make cfg.servers;

    networking.firewall.allowedUDPPorts = serverPorts;
    networking.firewall.allowedTCPPorts = serverPorts;
  };
}
