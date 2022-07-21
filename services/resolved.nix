{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.resolved;

  hosts_dirs = if cfg.hosts_dirs == [ ] then "" else "-A ${concatStringsSep " -A " cfg.hosts_dirs}";
  zones_dirs = if cfg.zones_dirs == [ ] then "" else "-Z ${concatStringsSep " -Z " cfg.zones_dirs}";

  package = { rustPlatform, fetchFromGitHub, ... }: rustPlatform.buildRustPackage rec {
    pname = "resolved";
    version = "6e3c17f8deb44cec0314448288f153b5ca711095";

    src = fetchFromGitHub {
      owner = "barrucadu";
      repo = pname;
      rev = version;
      sha256 = "sha256-+0cFa8RuC4ofaDZSq189pTQ5/pV9F6OqlzeVDlZ/vKs=";
    };

    cargoSha256 = "sha256-+VFuQBmJAbZQ3xxVoiwXHpCi544x7JlaElyJGPT6Vuc=";
  };
  resolved = pkgs.callPackage package { };
in
{
  # is this bad? eh, probably fine...
  disabledModules = [
    "system/boot/resolved.nix"
  ];

  options.services.resolved = {
    enable = mkOption { type = types.bool; default = false; };
    interface = mkOption { type = types.str; default = "0.0.0.0"; };
    metrics_port = mkOption { type = types.int; default = 9420; };
    authoritative_only = mkOption { type = types.bool; default = false; };
    forward_address = mkOption { type = types.nullOr types.str; default = null; };
    cache_size = mkOption { type = types.int; default = 512; };
    hosts_dirs = mkOption { type = types.listOf types.str; default = [ ]; };
    zones_dirs = mkOption { type = types.listOf types.str; default = [ ]; };
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
        ExecStart = "${resolved}/bin/resolved -i ${cfg.interface} --metrics-port ${toString cfg.metrics_port} ${if cfg.authoritative_only then "--authoritative-only " else ""}${if cfg.forward_address != null then "--forward-address ${cfg.forward_address} " else ""}-s ${toString cfg.cache_size} ${hosts_dirs} ${zones_dirs}";
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
        { name = "DNS Resolver"; folder = "Services"; options.path = ./grafana-dashboards/resolved.json; }
      ];
  };
}
