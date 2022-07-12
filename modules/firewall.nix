{ config, lib, ... }:

with lib;

let
  cfg = config.modules.firewall;

  readBlocklistFromFile = ''
    cat ${cfg.ipBlocklistFile} | sed 's/\s//g' | sed 's/#.*$//' | grep . | while read ip; do
      iptables -A barrucadu-ip-blocklist -s "$ip" -j DROP
    done
  '';
in
{
  options = {
    modules = {
      firewall = {
        enable = mkOption { type = types.bool; default = true; };
        ipBlocklist = mkOption { type = types.listOf types.str; default = [ ]; };
        ipBlocklistFile = mkOption { type = types.nullOr types.str; default = null; };
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.enable = true;
    networking.firewall.allowPing = true;
    networking.firewall.trustedInterfaces = if config.virtualisation.docker.enable then [ "docker0" ] else [ ];

    services.fail2ban.enable = true;

    networking.firewall.extraCommands = ''
      iptables -N barrucadu-ip-blocklist
      ${concatMapStringsSep "\n" (ip: "iptables -A barrucadu-ip-blocklist -s ${ip} -j DROP") cfg.ipBlocklist}
      ${if cfg.ipBlocklistFile == null then "" else readBlocklistFromFile}
      iptables -A barrucadu-ip-blocklist -j RETURN
      iptables -A INPUT -j barrucadu-ip-blocklist
    '';

    networking.firewall.extraStopCommands = ''
      if iptables -n --list barrucadu-ip-blocklist &>/dev/null; then
        iptables -D INPUT -j barrucadu-ip-blocklist
        iptables -F barrucadu-ip-blocklist
        iptables -X barrucadu-ip-blocklist
      fi
    '';
  };
}
