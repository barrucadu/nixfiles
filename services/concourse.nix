{ config, lib, ... }:

with lib;
let
  cfg = config.services.concourse;
  backend = config.virtualisation.oci-containers.backend;

  # https://github.com/NixOS/nixpkgs/issues/104750
  serviceConfigForContainerLogging = { StandardOutput = mkForce "journal"; StandardError = mkForce "journal"; };
in
{
  options.services.concourse = {
    enable = mkOption { type = types.bool; default = false; };
    execStartPre = mkOption { type = types.nullOr types.str; default = null; };
    dockerVolumeDir = mkOption { type = types.path; };
    concourseTag = mkOption { type = types.str; default = "7.1"; };
    githubUser = mkOption { type = types.str; default = "barrucadu"; };
    httpPort = mkOption { type = types.int; default = 3001; };
    metricsPort = mkOption { type = types.int; default = 9001; };
    postgresTag = mkOption { type = types.str; default = "13"; };
    workerScratchDir = mkOption { type = types.nullOr types.path; default = null; };
    environmentFile = mkOption { type = types.str; };
  };

  config = mkIf cfg.enable {
    # https://github.com/concourse/concourse/discussions/6529
    boot.kernelParams = [ "systemd.unified_cgroup_hierarchy=0" ];

    virtualisation.oci-containers.containers.concourse-web = {
      autoStart = true;
      image = "concourse/concourse:${cfg.concourseTag}";
      cmd = [ "web" ];
      environment = {
        "CONCOURSE_POSTGRES_HOST" = "concourse-db";
        "CONCOURSE_POSTGRES_USER" = "concourse";
        "CONCOURSE_POSTGRES_PASSWORD" = "concourse";
        "CONCOURSE_POSTGRES_DATABASE" = "concourse";
        "CONCOURSE_EXTERNAL_URL" = "https://cd.barrucadu.dev";
        "CONCOURSE_MAIN_TEAM_GITHUB_USER" = cfg.githubUser;
        "CONCOURSE_LOG_LEVEL" = "error";
        "CONCOURSE_GARDEN_LOG_LEVEL" = "error";
        "CONCOURSE_PROMETHEUS_BIND_IP" = "0.0.0.0";
        "CONCOURSE_PROMETHEUS_BIND_PORT" = "8088";
      };
      environmentFiles = [ cfg.environmentFile ];
      extraOptions = [ "--network=concourse_network" ];
      dependsOn = [ "concourse-db" ];
      ports = [
        "127.0.0.1:${toString cfg.httpPort}:8080"
        "127.0.0.1:${toString cfg.metricsPort}:8088"
      ];
      volumes = [
        "${toString cfg.dockerVolumeDir}/keys/web:/concourse-keys"
      ];
    };
    systemd.services."${backend}-concourse-web" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.concourse-worker = {
      autoStart = true;
      image = "concourse/concourse:${cfg.concourseTag}";
      cmd = [ "worker" "--ephemeral" ];
      environment = {
        "CONCOURSE_TSA_HOST" = "concourse-web:2222";
        "CONCOURSE_CONTAINERD_DNS_PROXY_ENABLE" = "false";
        "CONCOURSE_GARDEN_DNS_SERVER" = "1.1.1.1,8.8.8.8";
        "CONCOURSE_WORK_DIR" = mkIf (cfg.workerScratchDir != null) "/workdir";
      };
      extraOptions = [ "--network=concourse_network" "--privileged" ];
      dependsOn = [ "concourse-web" ];
      volumes = [
        "${toString cfg.dockerVolumeDir}/keys/worker:/concourse-keys"
      ] ++ (if cfg.workerScratchDir == null then [ ] else [ "${cfg.workerScratchDir}:/workdir" ]);
    };
    systemd.services."${backend}-concourse-worker" = {
      preStart = mkIf (cfg.execStartPre != null) cfg.execStartPre;
      serviceConfig = serviceConfigForContainerLogging;
    };

    virtualisation.oci-containers.containers.concourse-db = {
      autoStart = true;
      image = "postgres:${cfg.postgresTag}";
      environment = {
        "POSTGRES_DB" = "concourse";
        "POSTGRES_USER" = "concourse";
        "POSTGRES_PASSWORD" = "concourse";
      };
      extraOptions = [ "--network=concourse_network" ];
      volumes = [ "${toString cfg.dockerVolumeDir}/pgdata:/var/lib/postgresql/data" ];
    };
    systemd.services."${backend}-concourse-db" = {
      preStart = "${backend} network create -d bridge concourse_network || true";
      serviceConfig = serviceConfigForContainerLogging;
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "${config.networking.hostName}-concourse";
        static_configs = [{ targets = [ "localhost:${toString config.services.concourse.metricsPort}" ]; }];
      }
    ];
    services.grafana.provision.dashboards =
      [
        { name = "Concourse"; folder = "Services"; options.path = ./grafana-dashboards/concourse.json; }
      ];
  };
}
