{ lib, ... }:

with lib;

{
  options.nixfiles.finder = {
    enable = mkOption { type = types.bool; default = false; };
    image = mkOption { type = types.str; };
    port = mkOption { type = types.int; default = 44986; };
    esTag = mkOption { type = types.str; default = "8.0.0"; };
    mangaDir = mkOption { type = types.path; };
  };
}
