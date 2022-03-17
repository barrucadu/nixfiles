{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.services.resolved;

  hosts_dirs = if cfg.hosts_dirs == [ ] then "" else "-A ${concatStringsSep " -A " cfg.hosts_dirs}";
  zones_dirs = if cfg.zones_dirs == [ ] then "" else "-Z ${concatStringsSep " -Z " cfg.zones_dirs}";

  package = { rustPlatform, fetchFromGitHub, ... }: rustPlatform.buildRustPackage rec {
    pname = "resolved";
    version = "a63651bb869f641a8fd490a341706719ffbced3c";

    src = fetchFromGitHub {
      owner = "barrucadu";
      repo = pname;
      rev = version;
      sha256 = "1hdqc5fxxb9kh9ps6dzf67srx9b1wj4anxk9nx2znbcrh8wh1i68";
    };

    cargoSha256 = "1p9w2j10acw38fcjgv0gb8229p9x5dhw6hklz8vqbsx48aqylmn1";
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
    hosts_dirs = mkOption { type = types.listOf types.str; default = [ ]; };
    zones_dirs = mkOption { type = types.listOf types.str; default = [ ]; };
  };

  config = mkIf cfg.enable {
    systemd.services.resolved = {
      description = "barrucadu/resolved nameserver";
      serviceConfig = {
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        ExecStart = "${resolved}/bin/resolved -i ${cfg.interface} ${hosts_dirs} ${zones_dirs}";
        User = "nobody";
      };
    };

    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];
  };
}
