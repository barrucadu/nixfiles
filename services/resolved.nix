{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.resolved;

  hosts_dirs = if cfg.hosts_dirs == [ ] then "" else "-A ${concatStringsSep " -A " cfg.hosts_dirs}";
  zones_dirs = if cfg.zones_dirs == [ ] then "" else "-Z ${concatStringsSep " -Z " cfg.zones_dirs}";

  package = { rustPlatform, fetchFromGitHub, ... }: rustPlatform.buildRustPackage rec {
    pname = "resolved";
    version = "6b0e590d32a41a42cb2a4cbed7b1735d5369c965";

    src = fetchFromGitHub {
      owner = "barrucadu";
      repo = pname;
      rev = version;
      sha256 = "0k9z8prrky0m25chv5zrfg0kb3rr9740yj6cifi90m9ghkn59bqp";
    };

    cargoSha256 = "0apkg3ha89i8d1ha89x9flb8r8pihbwqfsj31ycbvd8an8wi83gi";
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
        ExecStart = "${resolved}/bin/resolved -i ${cfg.interface} ${if cfg.authoritative_only then "--authoritative-only " else ""}${if cfg.forward_address != null then "--forward-address ${cfg.forward_address} " else ""}-s ${toString cfg.cache_size} ${hosts_dirs} ${zones_dirs}";
        ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
        User = "nobody";
        Restart = "on-failure";
      };
    };

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
  };
}
