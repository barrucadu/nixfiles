{ lib, ... }:

with lib;

{
  options.nixfiles.eraseYourDarlings = {
    enable = mkOption { type = types.bool; default = false; };
    barrucaduPasswordFile = mkOption { type = types.str; };
    rootSnapshot = mkOption { type = types.str; default = "local/volatile/root@blank"; };
    persistDir = mkOption { type = types.path; default = "/persist"; };
    machineId = mkOption { type = types.str; };
  };
}
