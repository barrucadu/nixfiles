{ lib, ... }:

with lib;

{
  options.nixfiles.pleroma = {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.int; default = 46283; };
    pgTag = mkOption { type = types.str; default = "13"; };
    domain = mkOption { type = types.str; };
    faviconPath = mkOption { type = types.nullOr types.path; default = null; };
    instanceName = mkOption { type = types.nullOr types.str; default = null; };
    adminEmail = mkOption { type = types.str; default = "mike@barrucadu.co.uk"; };
    notifyEmail = mkOption { type = types.nullOr types.str; default = null; };
    allowRegistration = mkOption { type = types.bool; default = false; };
    secretsFile = mkOption { type = types.str; };
  };
}
