{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.resolved;

  hosts_dirs = if cfg.hosts_dirs == [ ] then "" else "-A ${concatStringsSep " -A " cfg.hosts_dirs}";
  zones_dirs = if cfg.zones_dirs == [ ] then "" else "-Z ${concatStringsSep " -Z " cfg.zones_dirs}";

  package = { rustPlatform, fetchFromGitHub, ... }: rustPlatform.buildRustPackage rec {
    pname = "resolved";
    version = "4003be29de5fbf33cbd62f4c668b4d35b3a73569";

    src = fetchFromGitHub {
      owner = "barrucadu";
      repo = pname;
      rev = version;
      sha256 = "12byha2451mv3g5k29r1gwddilfwwqsag79ynhgsv7zsadnw0i17";
    };

    cargoSha256 = "0pyi1lwc3xr5afh2c96vvvf9kqs54dm96kk5rm486iylscqd8rw1";
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
        ExecStart = "${resolved}/bin/resolved -i ${cfg.interface} -s ${toString cfg.cache_size} ${hosts_dirs} ${zones_dirs}";
        ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
        User = "nobody";
        Restart = "on-failure";
      };
    };

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
  };
}
