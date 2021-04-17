set -euo pipefail

export COMPOSE_PROJECT_NAME=bookdb

local_sync_dir="$(mktemp -d)"
remote_sync_dir="/tmp/bookdb-sync"
trap "rm -rf $local_sync_dir" EXIT

covers_dir="/bookdb-covers"

docker_compose_file="$(systemctl cat bookdb | grep "ExecStart=" | cut -d"'" -f2)"
bookdb_container="$(docker-compose -f "$docker_compose_file" ps -q bookdb)"

docker cp "${bookdb_container}:${covers_dir}" "${local_sync_dir}/covers"
docker exec -i "${bookdb_container}" env ES_HOST=http://db:9200 /app/dump-index.py > "${local_sync_dir}/dump.json"

scp -r "$local_sync_dir" "carcosa.barrucadu.co.uk:${remote_sync_dir}"
ssh carcosa.barrucadu.co.uk <<EOF
set -euo pipefail

export COMPOSE_PROJECT_NAME=bookdb

trap "rm -rf $remote_sync_dir" EXIT
docker_compose_file="\$(systemctl cat bookdb | grep "ExecStart=" | cut -d"'" -f2)"
bookdb_container="\$(docker-compose -f "\$docker_compose_file" ps -q bookdb)"

cd "$remote_sync_dir"
docker cp covers/. "\${bookdb_container}:${covers_dir}"
docker exec -i "\$bookdb_container" env DELETE_EXISTING_INDEX=1 ES_HOST=http://db:9200 /app/create-index.py - < dump.json
EOF
