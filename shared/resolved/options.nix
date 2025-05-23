{ lib, ... }:

with lib;

{
  options.nixfiles.resolved = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the [resolved](https://github.com/barrucadu/resolved) service.
      '';
    };

    address = mkOption {
      type = types.str;
      default = "0.0.0.0:53";
      description = ''
        Address to listen on.
      '';
    };

    metricsAddress = mkOption {
      type = types.str;
      default = "127.0.0.1:9420";
      description = ''
        Address to listen on to serve Prometheus metrics.
      '';
    };

    authoritativeOnly = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Only answer queries for which this server is authoritative: do not
        perform recursive or forwarding resolution.
      '';
    };

    protocolMode = mkOption {
      type = types.str;
      default = "only-v4";
      description = ''
        How to choose between connecting to upstream nameservers over IPv4 or
        IPv6 when acting as a recursive resolver.
      '';
    };

    forwardAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Act as a forwarding resolver, not a recursive resolver: forward queries
        which can't be answered from local state to this nameserver and cache
        the result.
      '';
    };

    cacheSize = mkOption {
      type = types.int;
      default = 512;
      description = ''
        How many records to hold in the cache.
      '';
    };

    hostsDirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of directories to read hosts files from.
      '';
    };

    zonesDirs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of directories to read zone files from.
      '';
    };

    useDefaultZones = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Include the default zone files.
      '';
    };

    logLevel = mkOption {
      type = types.str;
      default = "dns_resolver=info,resolved=info";
      description = ''
        Verbosity of the log messages.
      '';
    };

    logFormat = mkOption {
      type = types.str;
      default = "json,no-time";
      description = ''
        Format of the log messages.
      '';
    };
  };
}
