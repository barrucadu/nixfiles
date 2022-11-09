{ config, lib, pkgs, pkgsUnstable, ... }:

with lib;
let
  cfg = config.nixfiles.resolved;

  package = { rustPlatform, fetchFromGitHub, ... }: rustPlatform.buildRustPackage rec {
    pname = "resolved";
    version = "5f7ca9ef5756198f0ee7c1eb5a8826cbf0007f88";

    src = fetchFromGitHub {
      owner = "barrucadu";
      repo = pname;
      rev = version;
      sha256 = "sha256-NBOx+0YAg6h9+5mor4eaJbRKZ4IaHl35azs6EVcIetc=";
    };

    cargoSha256 = "sha256-2nJcvonKgqN7qSUJTJdwUg1e7eKEU6yhAg0/rrfPOHs=";

    postInstall = ''
      cd config
      find . -type f -exec install -Dm 755 "{}" "$out/etc/resolved/{}" \;
    '';
  };
  resolved = pkgsUnstable.callPackage package { };
in
{
  options.nixfiles.resolved = {
    enable = mkOption { type = types.bool; default = false; };
    interface = mkOption { type = types.str; default = "0.0.0.0"; };
    metrics_port = mkOption { type = types.int; default = 9420; };
    authoritative_only = mkOption { type = types.bool; default = false; };
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
          "${resolved}/bin/resolved"
          "-i ${cfg.interface}"
          "-s ${toString cfg.cache_size}"
          "--metrics-port ${toString cfg.metrics_port}"
          (if cfg.authoritative_only then "--authoritative-only " else "")
          (if cfg.forward_address != null then "--forward-address ${cfg.forward_address} " else "")
          (if cfg.hosts_dirs == [ ] then "" else "-A ${concatStringsSep " -A " cfg.hosts_dirs}")
          (if cfg.use_default_zones then "-Z ${resolved}/etc/resolved/zones" else "")
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
        static_configs = [{ targets = [ "localhost:${toString cfg.metrics_port}" ]; }];
      }
    ];
    services.grafana.provision.dashboards =
      [
        { name = "DNS Resolver"; folder = "Services"; options.path = ./dashboard.json; }
      ];
  };
}
