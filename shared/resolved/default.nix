{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.resolved;
in
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

  config = mkIf cfg.enable {
    systemd.services.resolved = {
      description = "barrucadu/resolved nameserver";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        ExecStart = concatStringsSep " " [
          "${pkgs.nixfiles.resolved}/bin/resolved"
          "-i ${cfg.address}"
          "-s ${toString cfg.cache_size}"
          "--metrics-address ${cfg.metrics_address}"
          "--protocol-mode ${cfg.protocol_mode}"
          (if cfg.authoritative_only then "--authoritative-only " else "")
          (if cfg.forward_address != null then "--forward-address ${cfg.forward_address} " else "")
          (if cfg.hosts_dirs == [ ] then "" else "-A ${concatStringsSep " -A " cfg.hosts_dirs}")
          (if cfg.use_default_zones then "-Z ${pkgs.nixfiles.resolved}/etc/resolved/zones" else "")
          (if cfg.zones_dirs == [ ] then "" else "-Z ${concatStringsSep " -Z " cfg.zones_dirs}")
        ];
        ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
        DynamicUser = "true";
        Restart = "on-failure";
      };
      environment = {
        RUST_LOG = cfg.log_level;
        RUST_LOG_FORMAT = cfg.log_format;
      };
    };

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    services.prometheus.scrapeConfigs = [
      {
        job_name = "${config.networking.hostName}-resolved";
        static_configs = [{ targets = [ cfg.metrics_address ]; }];
      }
    ];
    services.grafana.provision.dashboards.settings.providers =
      [
        { name = "DNS Resolver"; folder = "Services"; options.path = ./dashboard.json; }
      ];
  };
}
