#!/usr/bin/env bash

set -euo pipefail

local_sync_dir="$(mktemp -d)"
remote_sync_dir="/tmp/bookmarks-sync"
es_host="$(systemctl cat bookmarks | grep ES_HOST | cut -d'=' -f3 | sed 's/"//')"
python="$(systemctl cat bookmarks | grep ExecStart | sed 's/^ExecStart=//' | sed 's/gunicorn.*/python/')"

# shellcheck disable=SC2064
trap "rm -rf $local_sync_dir" EXIT

env "ES_HOST=$es_host" "$python" -m bookmarks.index.dump > "${local_sync_dir}/dump.json"

scp -r "$local_sync_dir" "carcosa.barrucadu.co.uk:${remote_sync_dir}"

# shellcheck disable=SC2087
ssh carcosa.barrucadu.co.uk <<EOF
set -euo pipefail

es_host="\$(systemctl cat bookmarks | grep ES_HOST | cut -d'=' -f3 | sed 's/"//')"
python="\$(systemctl cat bookmarks | grep ExecStart | sed 's/^ExecStart=//' | sed 's/gunicorn.*/python/')"

trap "rm -rf $remote_sync_dir" EXIT

cd "$remote_sync_dir"
env DELETE_EXISTING_INDEX=1 ES_HOST=\$es_host \$python -m bookmarks.index.create - < dump.json
EOF
