set -euo pipefail

export COMPOSE_PROJECT_NAME=bookmarks

local_sync_dir="$(mktemp -d)"
remote_sync_dir="/tmp/bookmarks-sync"
trap "rm -rf $local_sync_dir" EXIT

docker_compose_file="$(systemctl cat bookmarks | grep "ExecStart=" | cut -d"'" -f2)"
bookmarks_container="$(docker-compose -f "$docker_compose_file" ps -q bookmarks)"

docker exec -i "${bookmarks_container}" env ES_HOST=http://db:9200 /app/dump-index.py > "${local_sync_dir}/dump.json"

scp -r "$local_sync_dir" "carcosa.barrucadu.co.uk:${remote_sync_dir}"
ssh carcosa.barrucadu.co.uk <<EOF
set -euo pipefail

export COMPOSE_PROJECT_NAME=bookmarks

trap "rm -rf $remote_sync_dir" EXIT
docker_compose_file="\$(systemctl cat bookmarks | grep "ExecStart=" | cut -d"'" -f2)"
bookmarks_container="\$(docker-compose -f "\$docker_compose_file" ps -q bookmarks)"

cd "$remote_sync_dir"
docker exec -i "\$bookmarks_container" env DELETE_EXISTING_INDEX=1 ES_HOST=http://db:9200 /app/create-index.py - < dump.json
EOF
