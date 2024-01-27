# Manage regular incremental, compressed, and encrypted backups with [restic][].
#
# Backups are uploaded to the `barrucadu-backups-a19c48` [B2][] bucket.
#
# List all the snapshots with:
#
# ```bash
# nix run .#backups                                # all snapshots
# nix run .#backups -- snapshots --host <hostname> # for a specific host
# nix run .#backups -- snapshots --tag <tag>       # for a specific tag
# ```
#
# Restore a snapshot to `<restore-dir>` with:
#
# ```bash
# nix run .#backups restore <snapshot> [<restore-dir>]
# ```
#
# If unspecified, the snapshot is restored to `/tmp/restic-restore-<snapshot>`.
#
# **Alerts:**
#
# - Creating or uploading a snapshot fails.
#
# [restic]: https://restic.net/
# [B2]: https://www.backblaze.com/
{ config, lib, pkgs, ... }:

with lib;

let
  repo = "b2:barrucadu-backups-a19c48:nixfiles/restic";

  cfg = config.nixfiles.restic-backups;

  mkSudoRule = rule: {
    users = [ config.users.users.backups.name ];
    runAs = rule.runAs;
    commands = [{ command = rule.command; options = [ "NOPASSWD" ]; }];
  };

  mkBackup = name: options:
    let
      serviceName = "restic-backups-${name}";
      filesFrom = "/run/${serviceName}/includes";
    in
    nameValuePair serviceName {
      inherit (options) startAt;
      environment = {
        RESTIC_CACHE_DIR = "%C/${serviceName}";
        RESTIC_REPOSITORY = repo;
      };
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.restic}/bin/restic backup --tag ${name} --files-from=${filesFrom}";
        User = config.users.users.backups.name;
        CacheDirectory = serviceName;
        CacheDirectoryMode = "0700";
        RuntimeDirectory = "${serviceName} ${serviceName}/generated-files";
        WorkingDirectory = "/run/${serviceName}/generated-files";
        PrivateTmp = true;
        EnvironmentFile = cfg.environmentFile;
        AmbientCapabilities = "CAP_DAC_READ_SEARCH";
      };
      preStart = ''
        cat ${pkgs.writeText "paths" (concatStringsSep "\n" options.paths)} > ${filesFrom}
        ${optionalString (options.prepareCommand != null) options.prepareCommand}
      '';
      postStop = ''
        if [[ "$SERVICE_RESULT" != "success" ]]; then
          ${pkgs.awscli}/bin/aws sns publish \
            --topic-arn "arn:aws:sns:eu-west-1:197544591260:host-notifications" \
            --subject "Alert: ${config.networking.hostName}" \
            --message "${name} backup failed: ''${SERVICE_RESULT}"
        fi

        ${pkgs.coreutils}/bin/rm ${filesFrom}
        ${optionalString (options.cleanupCommand != null) options.cleanupCommand}
      '';
    };

  checkService =
    let
      serviceName = "restic-check";
    in
    {
      environment = {
        RESTIC_CACHE_DIR = "%C/${serviceName}";
        RESTIC_REPOSITORY = repo;
      };
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      startAt = cfg.checkRepositoryAt;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.restic}/bin/restic check";
        User = config.users.users.backups.name;
        RuntimeDirectory = serviceName;
        CacheDirectory = serviceName;
        CacheDirectoryMode = "0700";
        PrivateTmp = true;
        EnvironmentFile = cfg.environmentFile;
      };
      postStop = ''
        if [[ "$SERVICE_RESULT" != "success" ]]; then
          ${pkgs.awscli}/bin/aws sns publish \
            --topic-arn "arn:aws:sns:eu-west-1:197544591260:host-notifications" \
            --subject "Alert: ${config.networking.hostName}" \
            --message "restic-check service failed: ''${SERVICE_RESULT}"
        fi
      '';
    };
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    users.users.backups = {
      description = "backup service user";
      isSystemUser = true;
      group = "nogroup";
    };

    security.sudo.extraRules = map mkSudoRule cfg.sudoRules;

    systemd.services = mapAttrs' mkBackup cfg.backups // (if cfg.checkRepositoryAt == null then { } else { "restic-check" = checkService; });
  };
}
