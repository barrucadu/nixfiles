# [Forgejo][] is git forge (I'll never like that term).  This module sets up an
# instance with user registration disabled and an admin user set up.  The admin
# user password path must be readable by the forgejo user.
#
# After initialising the instance log into the admin account and:
#
# 1. Set up non-admin users for normal usage.
# 2. Generate a token for the runner, and update this configuration.
#
# Forgejo uses a containerised postgres database.
#
# **Backups:** the postgres database and state files (as a forgejo dump).
#
# [Forgejo]: https://forgejo.org/
{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.nixfiles.forgejo;
  dbSocketDir = "/run/forgejo-db";

  forgejoUser = config.services.forgejo.user;
  forgejoGroup = config.services.forgejo.group;
in
{
  imports = [
    ./erase-your-darlings.nix
    ./options.nix
  ];

  config = mkIf cfg.enable {
    services.forgejo = {
      enable = true;
      database = {
        createDatabase = false;
        socket = dbSocketDir;
        type = "postgres";
      };
      dump = {
        enable = true;
        type = "tar.xz";
      };
      settings = {
        actions = {
          ENABLED = true;
        };
        server = {
          DOMAIN = cfg.domain;
          ROOT_URL = "https://${cfg.domain}/";
          HTTP_PORT = cfg.port;
          SSH_PORT = lib.head config.services.openssh.ports;
        };
        service = {
          DISABLE_REGISTRATION = true;
          REQUIRE_SIGNIN_VIEW = true;
          ENABLE_BASIC_AUTHENTICATION = false;
          ENABLE_TIMETRACKING = false;
          DEFAULT_USER_VISIBILITY = "limited";
          DEFAULT_ORG_VISIBILITY = "limited";
        };
        mailer = {
          ENABLED = false;
        };
      };
    };

    systemd.services.forgejo = {
      after = [ "${config.nixfiles.oci-containers.backend}-pleroma-db.service" ];
      requires = [ "${config.nixfiles.oci-containers.backend}-pleroma-db.service" ];
      preStart = let 
        cmd = "${lib.getExe config.services.forgejo.package} admin user";
      in ''
        ${cmd} create --admin --email "root@localhost" --username ${cfg.adminUserName} --password "$(tr -d '\n' < ${cfg.adminUserPasswordPath})" || true
        ${cmd} change-password --username ${cfg.adminUserName} --password "$(tr -d '\n' < ${cfg.adminUserPasswordPath})" || true
      '';
    };

    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.default = mkIf (cfg.runnerTokenPath != null) {
        enable = true;
        name = "default";
        url = config.services.forgejo.settings.server.ROOT_URL;
        tokenFile = cfg.runnerTokenPath;
        labels = [
          "ubuntu-latest:docker://node:25-trixie"
        ];
      };
    };

    users.users."${forgejoUser}".uid = 980;
    users.groups."${forgejoGroup}".gid = 980;

    nixfiles.oci-containers.pods.forgejo.containers.db = {
      image = "mirror.gcr.io/postgres:${cfg.postgresTag}";
      environment = {
        "POSTGRES_DB" = "forgejo";
        "POSTGRES_USER" = "forgejo";
        "POSTGRES_PASSWORD" = "forgejo";
      };
      volumes = [
        { name = "pgdata"; inner = "/var/lib/postgresql"; }
        { host = dbSocketDir; inner = "/var/run/postgresql"; }
      ];
    };

    systemd.tmpfiles.rules = [ "d ${dbSocketDir} 0700 ${forgejoUser} ${forgejoGroup}" ];

    nixfiles.restic-backups.backups.forgejo = {
      paths = [
        config.services.forgejo.dump.backupDir
      ];
    };
  };
}
