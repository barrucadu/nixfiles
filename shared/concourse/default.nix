# [Concourse CI][] is a "continuous thing-doer", it's a CI / CD tool.  This
# module sets up a single-user instance, with GitHub authentication.
#
# Concourse uses a containerised postgres database.
#
# Provides a grafana dashboard.
#
# **Backups:** the postgres database.
#
# [Concourse CI]: https://concourse-ci.org/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.concourse;
  backend = config.nixfiles.oci-containers.backend;
  backendPkg = if backend == "docker" then pkgs.docker else pkgs.podman;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    nixfiles.oci-containers.pods.concourse = {
      containers = {
        web = {
          image = "mirror.gcr.io/concourse/concourse:${cfg.concourseTag}";
          cmd = [ "web" ];
          environment = {
            "CONCOURSE_POSTGRES_HOST" = "concourse-db";
            "CONCOURSE_POSTGRES_USER" = "concourse";
            "CONCOURSE_POSTGRES_PASSWORD" = "concourse";
            "CONCOURSE_POSTGRES_DATABASE" = "concourse";
            "CONCOURSE_EXTERNAL_URL" = "https://cd.barrucadu.dev";
            "CONCOURSE_MAIN_TEAM_GITHUB_USER" = cfg.githubUser;
            "CONCOURSE_LOG_LEVEL" = "error";
            "CONCOURSE_PROMETHEUS_BIND_IP" = "0.0.0.0";
            "CONCOURSE_PROMETHEUS_BIND_PORT" = "8088";
            "CONCOURSE_BAGGAGECLAIM_RESPONSE_HEADER_TIMEOUT" = "30m";
          };
          environmentFiles = [ cfg.environmentFile ];
          dependsOn = [ "concourse-db" ];
          ports = [
            { host = cfg.port; inner = 8080; }
            { host = cfg.metricsPort; inner = 8088; }
          ];
          volumes = [{ name = "keys/web"; inner = "/concourse-keys"; }];
        };

        worker = {
          image = "mirror.gcr.io/concourse/concourse:${cfg.concourseTag}";
          cmd = [ "worker" "--ephemeral" ];
          environment = {
            "CONCOURSE_TSA_HOST" = "concourse-web:2222";
            "CONCOURSE_RUNTIME" = "containerd";
            "CONCOURSE_CONTAINERD_DNS_PROXY_ENABLE" = "false";
            "CONCOURSE_CONTAINERD_DNS_SERVER" = "1.1.1.1,8.8.8.8";
            "CONCOURSE_WORK_DIR" = mkIf (cfg.workerScratchDir != null) "/workdir";
          };
          extraOptions = [ "--privileged" ];
          dependsOn = [ "concourse-web" ];
          volumes =
            [{ name = "keys/worker"; inner = "/concourse-keys"; }] ++
            (if cfg.workerScratchDir == null then [ ] else [{ host = cfg.workerScratchDir; inner = "/workdir"; }]);
        };

        db = {
          image = "mirror.gcr.io/postgres:${cfg.postgresTag}";
          environment = {
            "POSTGRES_DB" = "concourse";
            "POSTGRES_USER" = "concourse";
            "POSTGRES_PASSWORD" = "concourse";
          };
          volumes = [{ name = "pgdata"; inner = "/var/lib/postgresql/data"; }];
        };
      };
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "${config.networking.hostName}-concourse";
        static_configs = [{ targets = [ "localhost:${toString cfg.metricsPort}" ]; }];
      }
    ];
    services.grafana.provision.dashboards.settings.providers =
      [
        { name = "Concourse"; folder = "Services"; options.path = ./dashboard.json; }
      ];

    nixfiles.restic-backups.backups.concourse = {
      prepareCommand = ''
        /run/wrappers/bin/sudo ${backendPkg}/bin/${backend} exec -i concourse-db pg_dump -U concourse --no-owner -Fc concourse > postgres.dump
      '';
      paths = [
        "postgres.dump"
      ];
    };
    nixfiles.restic-backups.sudoRules = [
      { command = "${backendPkg}/bin/${backend} exec -i concourse-db pg_dump -U concourse --no-owner -Fc concourse"; }
    ];
  };
}
