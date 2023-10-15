# [resolved][] is a recursive DNS server for LAN DNS.
#
# Enabling this module also provisions a [Grafana][] dashboard.
#
# [resolved]: https://github.com/barrucadu/resolved
# [Grafana]: https://grafana.com/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.resolved;
in
{
  imports = [
    ./options.nix
  ];

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
