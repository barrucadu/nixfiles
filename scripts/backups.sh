set -Ee

export RESTIC_REPOSITORY="b2:barrucadu-backups-a19c48:nixfiles/restic"

COMMAND=$1
TARGET=$(hostname)

if [[ -z "$COMMAND" ]]; then
  COMMAND=snapshots
else
  shift
fi

if [[ ! -f "hosts/${TARGET}/secrets.yaml" ]]; then
  echo "unknown host '${TARGET}'"
  exit 1
fi

sops_env=$(sops -d --extract '["nixfiles"]["restic-backups"]["env"]' "hosts/${TARGET}/secrets.yaml")
# shellcheck disable=SC2163
# shellcheck disable=SC2086
export $sops_env

case "$COMMAND" in
  check | snapshots)
    restic "$COMMAND" "$@"
    ;;

  restore)
    SNAPSHOT=$1
    shift

    if [[ -z "$SNAPSHOT" ]]; then
      echo "usage: 'restore <snapshot> [<restore-dir>]'"
      exit 1
    fi

    RESTORE_DIR=$1
    if [[ -z "$RESTORE_DIR" ]]; then
      RESTORE_DIR="/tmp/restic-restore-${SNAPSHOT}"
    else
      shift
    fi

    restic restore "$SNAPSHOT" --target "$RESTORE_DIR" "$@"
    ;;

  *)
    echo "unknown command '$COMMAND'"
    exit 1
    ;;
esac
