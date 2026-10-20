#!/usr/bin/env bash
# Start, stop or list the disposable test databases.
#   docker/test-db.sh up postgres      # start + seed one engine
#   docker/test-db.sh down postgres    # stop and delete its data
#   docker/test-db.sh list             # engines with a compose file
set -euo pipefail
cd "$(dirname "$0")"
command=${1:-list}
engine=${2:-}
case "$command" in
  list) for f in */compose.yaml; do echo "${f%%/*}"; done ;;
  up) docker compose -f "$engine/compose.yaml" up -d --wait --wait-timeout 600 "${@:3}" || true
      # One-shot seed/build jobs aren't covered by --wait; block until they exit.
      for job in seed build; do
        if docker compose -f "$engine/compose.yaml" config --services | grep -qx "$job"; then
          docker compose -f "$engine/compose.yaml" wait "$job" >/dev/null
        fi
      done
      docker compose -f "$engine/compose.yaml" ps -a ;;
  down) docker compose -f "$engine/compose.yaml" down -v --remove-orphans ;;
  logs) docker compose -f "$engine/compose.yaml" logs --tail 100 ;;
  *) echo "usage: $0 {list|up|down|logs} <engine>" >&2; exit 2 ;;
esac
