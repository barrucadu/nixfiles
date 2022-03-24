{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.resolved;

  hosts_dirs = if cfg.hosts_dirs == [ ] then "" else "-A ${concatStringsSep " -A " cfg.hosts_dirs}";
  zones_dirs = if cfg.zones_dirs == [ ] then "" else "-Z ${concatStringsSep " -Z " cfg.zones_dirs}";

  package = { rustPlatform, fetchFromGitHub, ... }: rustPlatform.buildRustPackage rec {
    pname = "resolved";
    version = "e0e4dab02eab02133d3b6e2d4460a2226bb72a54";

    src = fetchFromGitHub {
      owner = "barrucadu";
      repo = pname;
      rev = version;
      sha256 = "0p9kh10f2kh7h3mdky16gx1j3amgzrd7bmzsawzq4gh3dwf64bmc";
    };

    cargoSha256 = "1y1d66224x19snrzax35ms6848lszd5690q3kr0c420wln9mr54q";
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
        User = "nobody";
        Restart = "on-failure";
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
  };
}
