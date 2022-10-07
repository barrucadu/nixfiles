#!/usr/bin/env bash

set -euo pipefail

local_sync_dir="$(mktemp -d)"
remote_sync_dir="/tmp/bookdb-sync"

# shellcheck disable=SC2064
trap "rm -rf $local_sync_dir" EXIT

docker cp "bookdb:/bookdb-covers" "${local_sync_dir}/covers"
docker exec -i bookdb env ES_HOST=http://bookdb-db:9200 /app/dump-index.py > "${local_sync_dir}/dump.json"

scp -r "$local_sync_dir" "carcosa.barrucadu.co.uk:${remote_sync_dir}"

# shellcheck disable=SC2087
ssh carcosa.barrucadu.co.uk <<EOF
set -euo pipefail

trap "rm -rf $remote_sync_dir" EXIT

cd "$remote_sync_dir"
docker cp covers/. "bookdb:/bookdb-covers"
docker exec -i bookdb env DELETE_EXISTING_INDEX=1 ES_HOST=http://bookdb-db:9200 /app/create-index.py - < dump.json
EOF
