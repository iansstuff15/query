#!/usr/bin/env bash
# Starts each engine's container, runs the live driver tests against it, then stops it.
#   docker/run-live-tests.sh postgres mysql        # specific engines (docker folder names)
#   docker/run-live-tests.sh                       # every engine with a compose file
set -uo pipefail
cd "$(dirname "$0")/.."
container_tmp="$HOME/Library/Containers/by-ian.query/Data/tmp"
engine_case() {
  case "$1" in
    postgres) echo postgreSQL ;; cockroachdb) echo cockroachDB ;; greenplum) echo greenplum ;; vertica) echo vertica ;;
    mysql) echo mySQL ;; mariadb) echo mariaDB ;; sqlserver) echo sqlServer ;; oracle) echo oracle ;;
    clickhouse) echo clickHouse ;; libsql) echo libSQL ;; sqlite) echo sqlite ;; duckdb) echo duckDB ;;
    bigquery) echo bigQuery ;; cassandra) echo cassandra ;; redis) echo redis ;; mongodb) echo mongoDB ;;
    elasticsearch) echo elasticsearch ;; dynamodb) echo dynamoDB ;;
  esac
}
engines=("$@")
[ ${#engines[@]} -eq 0 ] && engines=($(docker/test-db.sh list))
summary=()
for folder in "${engines[@]}"; do
  echo "=== $folder"
  docker/test-db.sh up "$folder" >/dev/null
  case "$folder" in
    sqlite) mkdir -p "$container_tmp" && cp docker/sqlite/data/app.sqlite "$container_tmp/" ;;
    duckdb) mkdir -p "$container_tmp" && cp docker/duckdb/data/app.duckdb "$container_tmp/" ;;
  esac
  if TEST_RUNNER_QUERY_LIVE_ENGINES="$(engine_case "$folder")" xcodebuild test -project query.xcodeproj -scheme query \
      -destination 'platform=macOS,arch=arm64' -only-testing:queryTests/LiveEngineTests -quiet; then
    summary+=("PASS $folder")
  else
    summary+=("FAIL $folder")
  fi
  docker/test-db.sh down "$folder" >/dev/null 2>&1
done
printf '%s\n' "${summary[@]}"
