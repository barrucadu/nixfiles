{ lib, ... }:

with lib;

{
  options.nixfiles.resolved = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Enable the resolved service.
      '';
    };

    address = mkOption {
      type = types.str;
      default = "0.0.0.0:53";
      description = mdDoc ''
        Address to listen on.
      '';
    };

    metrics_address = mkOption {
      type = types.str;
      default = "127.0.0.1:9420";
      description = mdDoc ''
        Address to listen on to serve Prometheus metrics.
      '';
    };

    authoritative_only = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Only answer queries for which this server is authoritative: do not
        perform recursive or forwarding resolution.
      '';
    };

    protocol_mode = mkOption {
      type = types.str;
      default = "only-v4";
      description = mdDoc ''
        How to choose between connecting to upstream nameservers over IPv4 or
        IPv6 when acting as a recursive resolver.
      '';
    };

    forward_address = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = mdDoc ''
        Act as a forwarding resolver, not a recursive resolver: forward queries
        which can't be answered from local state to this nameserver and cache
        the result.
      '';
    };

    cache_size = mkOption {
      type = types.int;
      default = 512;
      description = mdDoc ''
        How many records to hold in the cache.
      '';
    };

    hosts_dirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = mdDoc ''
        List of directories to read hosts files from.
      '';
    };

    zones_dirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = mdDoc ''
        List of directories to read zone files from.
      '';
    };

    use_default_zones = mkOption {
      type = types.bool;
      default = true;
      description = mdDoc ''
        Include the default zone files.
      '';
    };

    log_level = mkOption {
      type = types.str;
      default = "dns_resolver=info,resolved=info";
      description = mdDoc ''
        Verbosity of the log messages.
      '';
    };

    log_format = mkOption {
      type = types.str;
      default = "json,no-time";
      description = mdDoc ''
        Format of the log messages.
      '';
    };
  };
}
