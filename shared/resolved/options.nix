{ lib, ... }:

with lib;

{
  options.nixfiles.resolved = {
    enable = mkOption { type = types.bool; default = false; };
    address = mkOption { type = types.str; default = "0.0.0.0:53"; };
    metrics_address = mkOption { type = types.str; default = "127.0.0.1:9420"; };
    authoritative_only = mkOption { type = types.bool; default = false; };
    protocol_mode = mkOption { type = types.str; default = "only-v4"; };
    forward_address = mkOption { type = types.nullOr types.str; default = null; };
    cache_size = mkOption { type = types.int; default = 512; };
    hosts_dirs = mkOption { type = types.listOf types.str; default = [ ]; };
    zones_dirs = mkOption { type = types.listOf types.str; default = [ ]; };
    use_default_zones = mkOption { type = types.bool; default = true; };
    log_level = mkOption { type = types.str; default = "dns_resolver=info,resolved=info"; };
    log_format = mkOption { type = types.str; default = "json,no-time"; };
  };
}
