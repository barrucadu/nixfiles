#!/usr/bin/env bash

set -euo pipefail

local_sync_dir="$(mktemp -d)"
remote_sync_dir="/tmp/bookmarks-sync"

# shellcheck disable=SC2064
trap "rm -rf $local_sync_dir" EXIT

docker exec -i bookmarks env ES_HOST=http://bookmarks-db:9200 /app/dump-index.py > "${local_sync_dir}/dump.json"

scp -r "$local_sync_dir" "carcosa.barrucadu.co.uk:${remote_sync_dir}"

# shellcheck disable=SC2087
ssh carcosa.barrucadu.co.uk <<EOF
set -euo pipefail

trap "rm -rf $remote_sync_dir" EXIT

cd "$remote_sync_dir"
docker exec -i bookmarks env DELETE_EXISTING_INDEX=1 ES_HOST=http://bookmarks-db:9200 /app/create-index.py - < dump.json
EOF
