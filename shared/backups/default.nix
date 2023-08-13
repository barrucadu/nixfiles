{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nixfiles.backups;
  hostname = config.networking.hostName;

  runScript = cmd: name: source: ''
    echo "${name}"
    mkdir "${name}"
    pushd "${name}"
    if ! time ${cmd} "${pkgs.writeText "${name}.backup-script" source}"; then
      fail "Backup failed in ${name}"
    fi
    popd
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
  options.nixfiles.backups = {
    enable = mkOption { type = types.bool; default = false; };
    scripts = mkOption { type = types.attrsOf types.str; default = { }; };
    pythonScripts = mkOption { type = types.attrsOf types.str; default = { }; };
    environmentFile = mkOption { type = types.str; };
    onCalendarFull = mkOption { type = types.str; default = "monthly"; };
    onCalendarIncr = mkOption { type = types.str; default = "Mon, 04:00"; };
    user = mkOption { type = types.str; default = "barrucadu"; };
    group = mkOption { type = types.str; default = "users"; };
  };

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
  };
}
