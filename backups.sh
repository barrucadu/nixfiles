#!/usr/bin/env nix-shell
#!nix-shell -i bash -p duplicity "python3.withPackages (ps: [ps.boto3])" sops

set -e

COMMAND=${1:-status}
TARGET=${2:-$(hostname)}

if [[ ! -f "hosts/${TARGET}/secrets.yaml" ]]; then
  echo "unknown host '${TARGET}'"
  exit 1
fi

export $(sops -d --extract '["services"]["backups"]["env"]' "hosts/${TARGET}/secrets.yaml")

if [[ "$COMMAND" == "status" ]]; then
  duplicity                  \
    --s3-european-buckets    \
    --s3-use-multiprocessing \
    --s3-use-new-style       \
    --verbosity notice       \
    collection-status        \
    "boto3+s3://barrucadu-backups/${TARGET}"
elif [[ "$COMMAND" == "restore" ]]; then
  RESTORE_DIR="${RESTORE_DIR:-/tmp/backup-restore}"

  duplicity                  \
    --s3-european-buckets    \
    --s3-use-multiprocessing \
    --s3-use-new-style       \
    --verbosity notice       \
    restore                  \
    "boto3+s3://barrucadu-backups/${TARGET}" "$RESTORE_DIR"
else
  echo "unknown command '$COMMAND'"
  exit 1
fi
