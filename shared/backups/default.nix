# Manage regular incremental and full backups with [Duplicity][].
#
# Backups are encrypted and uploaded to the `barrucadu-backups` s3 bucket,
# [defined in the ops repo][].
#
# Check the status of a backup collection with:
#
# ```bash
# nix run .#backups                   # for the current host
# nix run .#backups status            # for the current host
# nix run .#backups status <hostname> # for another host
# ```
#
# Restore a backup to `/tmp/backup-restore` with:
#
# ```bash
# nix run .#backups restore            # for the current host
# nix run .#backups restore <hostname> # for another host
# ```
#
# Change the restore target by setting `$RESTORE_DIR`.
#
# **Alerts:**
#
# - A backup script terminates with an error.
# - Uploading the backup to s3 fails.
#
# [Duplicity]: https://duplicity.gitlab.io/
# [defined in the ops repo]: https://github.com/barrucadu/ops/blob/master/aws/backups.tf
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nixfiles.backups;
  hostname = config.networking.hostName;

  chown = name: "${pkgs.coreutils}/bin/chown -R ${cfg.user}.${cfg.group} ./${name}/";

  runScript = cmd: name: source: ''
    echo "${name}"
    mkdir "${name}"
    pushd "${name}"
    if ! time ${cmd} "${pkgs.writeText "${name}.backup-script" source}"; then
      fail "Backup failed in ${name}"
    fi
    popd
    /run/wrappers/bin/sudo ${chown name}
  '';

  script = pkgs.writeShellScript "backup.sh" ''
    set -e

    function fail(){
      echo "Backup failed: $1"
      aws sns publish --topic-arn "$TOPIC_ARN" --subject "Alert: ${hostname}" --message "$1"
      exit 1
    }

    BACKUP_TYPE=$1
    if [[ -z "$BACKUP_TYPE" ]]; then
      echo 'specify a backup type!'
      exit 1
    fi

    DIR=`mktemp -d`
    trap "rm -rf $DIR" EXIT
    cd $DIR

    mkdir "${hostname}"
    pushd "${hostname}"

    ${concatStringsSep "\n" (mapAttrsToList (runScript "bash -e -o pipefail") cfg.scripts)}
    ${concatStringsSep "\n" (mapAttrsToList (runScript "python3") cfg.pythonScripts)}

    popd

    if ! time duplicity --s3-european-buckets --s3-use-multiprocessing --s3-use-new-style --verbosity notice "$BACKUP_TYPE" "${hostname}" "boto3+s3://barrucadu-backups/${hostname}"; then
      fail "Backup upload failed"
    fi
  '';

  servicePath = with pkgs; [
    awscli
    bash
    coreutils
    curl
    (if config.nixfiles.oci-containers.backend == "docker" then docker else podman)
    duplicity
    git
    gnutar
    gzip
    jq
    openssh
    python3
    systemd
  ];

  serviceConfig = type: {
    ExecStart = "${script} ${type}";
    EnvironmentFile = cfg.environmentFile;
    User = cfg.user;
    Group = cfg.group;
  };
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    systemd.services.backup-scripts-full = {
      description = "Take a full backup";
      startAt = cfg.onCalendarFull;
      path = servicePath;
      serviceConfig = serviceConfig "full";
    };

    systemd.services.backup-scripts-incr = {
      description = "Take an incremental backup";
      startAt = cfg.onCalendarIncr;
      path = servicePath;
      serviceConfig = serviceConfig "incr";
    };

    security.sudo.extraRules =
      let
        mkRule = rule: {
          users = [ cfg.user ];
          runAs = rule.runAs;
          commands = [{ command = rule.command; options = [ "NOPASSWD" ]; }];
        };
        mkChownRule = name: _: mkRule { command = chown name; runAs = "root"; };
      in
      map mkRule cfg.sudoRules ++ mapAttrsToList mkChownRule cfg.scripts ++ mapAttrsToList mkChownRule cfg.pythonScripts;
  };
}
