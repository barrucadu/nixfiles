{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.minecraft;

  serverPorts = mapAttrsToList (_: server: server.port) cfg.servers;
in
{
  # yes I know there's a NixOS minecraft module but it uses the
  # Minecraft in nixpkgs whereas I want to run modded servers and
  # packaging one is a pain.
  options.nixfiles.minecraft = {
    enable = mkOption { type = types.bool; default = false; };
    dataDir = mkOption { type = types.path; default = "/srv/minecraft"; };
    servers = mkOption {
      type = types.attrsOf (types.submodule
        {
          options = {
            autoStart = mkOption { type = types.bool; default = true; };
            port = mkOption { type = types.int; };
            jar = mkOption { type = types.str; default = "minecraft-server.jar"; };
            jre = mkOption { type = types.package; default = pkgs.jdk17_headless; };
            jvmOpts = mkOption { type = types.separatedString " "; default = "-Xmx4G -Xms4G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M"; };
          };
        }
      );
      default = { };
    };
  };

  config = mkIf cfg.enable {
    # from https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/games/minecraft-server.nix
    users.users.minecraft = {
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
