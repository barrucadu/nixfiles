{ lib, pkgs, ... }:

with lib;

{
  options.nixfiles.minecraft = {
    enable = mkOption { type = types.bool; default = false; };
    dataDir = mkOption { type = types.path; default = "/var/lib/minecraft"; };
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
}
