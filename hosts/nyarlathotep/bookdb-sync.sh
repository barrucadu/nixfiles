export COMPOSE_PROJECT_NAME=bookdb

local_sync_dir="$(mktemp -d)"
remote_sync_dir="/tmp/bookdb-sync"
trap "rm -rf $local_sync_dir" EXIT

covers_dir="/bookdb/static/covers"

docker_compose_file="$(systemctl cat bookdb | grep ExecStart | cut -d"'" -f2)"
bookdb_container="$(docker-compose -f "$docker_compose_file" ps -q bookdb)"
postgres_container="$(docker-compose -f "$docker_compose_file" ps -q postgres)"

docker cp "${bookdb_container}:${covers_dir}" "${local_sync_dir}/covers"
docker exec -i "${postgres_container}" pg_dump --clean --if-exists -U bookdb -w -d bookdb > "${local_sync_dir}/restore.sql"

scp -r "$local_sync_dir" "dunwich.barrucadu.co.uk:${remote_sync_dir}"
ssh dunwich.barrucadu.co.uk <<EOF
export COMPOSE_PROJECT_NAME=bookdb

trap "rm -rf $remote_sync_dir" EXIT
docker_compose_file="\$(systemctl cat bookdb | grep ExecStart | cut -d"'" -f2)"
bookdb_container="\$(docker-compose -f "\$docker_compose_file" ps -q bookdb)"
postgres_container="\$(docker-compose -f "\$docker_compose_file" ps -q postgres)"

cd "$remote_sync_dir"
docker cp covers/. "\${bookdb_container}:${covers_dir}"
docker exec -i "\$postgres_container" psql --single-transaction -U bookdb -w -d bookdb < restore.sql
EOF
