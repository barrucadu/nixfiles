{ config, lib, ... }:

with lib;
let
  cfg = config.services.pihole;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  # For now, static records (etc) are configyred by making changes to
  # the docker volumes directly.
  options.services.pihole = {
    enable = mkOption { type = types.bool; default = false; };
    dockerTag = mkOption { type = types.str; };
    serverIP = mkOption { type = types.str; };
    password = mkOption { type = types.nullOr types.str; default = null; };
    upstreamDNS = mkOption { type = types.listOf types.str; default = [ "1.1.1.1" "8.8.8.8" ]; };
    httpPort = mkOption { type = types.int; default = 3000; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    dockerVolumeDir = mkOption { type = types.path; };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.containers.pihole = {
      autoStart = true;
      image = "pihole/pihole:${cfg.dockerTag}";
      environment = {
        "WEBPASSWORD" = cfg.password;
        "ServerIP" = cfg.serverIP;
        "PIHOLE_DNS_" = concatStringsSep ";" cfg.upstreamDNS;
      };
      ports = [
        "127.0.0.1:${toString cfg.httpPort}:80"
        "${cfg.serverIP}:53:53/tcp"
        "${cfg.serverIP}:53:53/udp"
      ];
      volumes = [
        "${toString cfg.dockerVolumeDir}/etc-pihole:/etc/pihole"
        "${toString cfg.dockerVolumeDir}/etc-dnsmasq.d:/etc/dnsmasq.d"
      ];
    };
    systemd.services."${backend}-pihole" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    services.prometheus.exporters.pihole.enable = config.services.prometheus.enable;
    services.prometheus.exporters.pihole.piholeHostname = "pi.hole";
    services.prometheus.exporters.pihole.password = cfg.password;

    services.prometheus.scrapeConfigs = [
      {
        job_name = "${config.networking.hostName}-pihole";
        static_configs = [{ targets = [ "localhost:${toString config.services.prometheus.exporters.pihole.port}" ]; }];
      }
    ];
  };
}
