# [resolved][] is a recursive DNS server for LAN DNS.
#
# Provides a grafana dashboard.
#
# [resolved]: https://github.com/barrucadu/resolved
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
          "-s ${toString cfg.cacheSize}"
          "--metrics-address ${cfg.metricsAddress}"
          "--protocol-mode ${cfg.protocolMode}"
          (if cfg.authoritativeOnly then "--authoritative-only " else "")
          (if cfg.forwardAddress != null then "--forward-address ${cfg.forwardAddress} " else "")
          (if cfg.hostsDirs == [ ] then "" else "-A ${concatStringsSep " -A " cfg.hostsDirs}")
          (if cfg.useDefaultZones then "-Z ${pkgs.nixfiles.resolved}/etc/resolved/zones" else "")
          (if cfg.zonesDirs == [ ] then "" else "-Z ${concatStringsSep " -Z " cfg.zonesDirs}")
        ];
        ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
        DynamicUser = "true";
        Restart = "on-failure";
      };
      environment = {
        RUST_LOG = cfg.logLevel;
        RUST_LOG_FORMAT = cfg.logFormat;
      };
    };

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    services.prometheus.scrapeConfigs = [
      {
        job_name = "${config.networking.hostName}-resolved";
        static_configs = [{ targets = [ cfg.metricsAddress ]; }];
      }
    ];
    services.grafana.provision.dashboards.settings.providers =
      [
        { name = "DNS Resolver"; folder = "Services"; options.path = ./dashboard.json; }
      ];
  };
}
