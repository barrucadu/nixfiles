{ lib, ... }:

with lib;

{
  options.nixfiles.backups = {
    enable = mkOption { type = types.bool; default = false; };
    scripts = mkOption { type = types.attrsOf types.str; default = { }; };
    pythonScripts = mkOption { type = types.attrsOf types.str; default = { }; };
    sudoRules = mkOption {
      type = types.listOf (types.submodule {
        options = {
          command = mkOption { type = types.str; };
          runAs = mkOption { type = types.str; default = "ALL:ALL"; };
        };
      });
      default = { };
    };
    environmentFile = mkOption { type = types.str; };
    onCalendarFull = mkOption { type = types.str; default = "monthly"; };
    onCalendarIncr = mkOption { type = types.str; default = "Mon, 04:00"; };
    user = mkOption { type = types.str; default = "barrucadu"; };
    group = mkOption { type = types.str; default = "users"; };
  };
}
