{ lib, pkgs, ... }:

with lib;

{
  options.nixfiles.minecraft = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the Minecraft service.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/minecraft";
      description = mdDoc ''
        Directory to store data files in.

        If the `erase-your-darlings` module is enabled, this is overridden to be
        on the persistent volume.
      '';
    };

    servers = mkOption {
      type = types.attrsOf (types.submodule
        {
          options = {
            autoStart = mkOption {
              type = types.bool;
              default = true;
              description = mdDoc ''
                Start this server on boot.
              '';
            };

            port = mkOption {
              type = types.int;
              description = mdDoc ''
                Port to open in the firewall.  This must match the port in the
                `server.properties` file.
              '';
            };

            jar = mkOption {
              type = types.str;
              default = "minecraft-server.jar";
              description = mdDoc ''
                Name of the JAR file to use.  This file must be in the working
                directory.
              '';
            };

            jre = mkOption {
              type = types.package;
              default = pkgs.jdk17_headless;
              description = mdDoc ''
                Java runtime package to use.
              '';
            };

            jvmOpts = mkOption {
              type = types.separatedString " ";
              default = "-Xmx4G -Xms4G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M";
              description = mdDoc ''
                Java runtime arguments.  Cargo cult these from a forum post and
                then never think about them again.
              '';
            };
          };
        }
      );
      default = { };
      description = mdDoc ''
        Attrset of minecraft server definitions.  Each server `{name}` is run in
        the working directory `''${dataDir}/{name}`.
      '';
    };
  };
}
