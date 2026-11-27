#!/usr/bin/env bash
# Loads every migration (0001 → newest) into a throwaway Postgres in Docker,
# then runs the behaviour tests in this folder. Never touches the live
# project.
#
#   supabase/tests/run.sh                      # all *_test.sql
#   supabase/tests/run.sh 0040_organizations   # just that test
#
# Docker can be local or remote, e.g. the ops server:
#   DOCKER_HOST=ssh://azureuser@reagan-server.tail55bf0e.ts.net supabase/tests/run.sh
# KEEP=1 leaves the container running (name printed) for poking around.
# PG_IMAGE picks the image (default postgres:17-alpine).
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
migrations="$here/../migrations"
image="${PG_IMAGE:-postgres:17-alpine}"
name="yna-migrations-test-$$"

cleanup() {
  if [[ "${KEEP:-}" == "1" ]]; then
    echo "Container left running: $name  (docker exec -it $name psql -U postgres)"
  else
    docker rm -f "$name" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

docker run -d --name "$name" -e POSTGRES_PASSWORD=test -e TZ=UTC "$image" >/dev/null
for _ in $(seq 1 60); do
  if docker exec "$name" pg_isready -U postgres -q 2>/dev/null \
     && docker exec "$name" psql -U postgres -tAc 'select 1' >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Stand-ins for pg_cron and pg_net, so `create extension` works.
extdir="$(docker exec "$name" pg_config --sharedir)/extension"
for f in pg_cron.control pg_cron--1.0.sql pg_net.control pg_net--1.0.sql; do
  docker exec -i "$name" sh -c "cat > '$extdir/$f'" < "$here/stubs/$f"
done

psql_file() {
  docker exec -i "$name" psql -U postgres -X -q -v ON_ERROR_STOP=1 --single-transaction -f - < "$1"
}

echo "• Supabase stubs"
psql_file "$here/stubs/supabase_stubs.sql"

for f in "$migrations"/[0-9][0-9][0-9][0-9]_*.sql; do
  echo "• $(basename "$f")"
  if ! out="$(psql_file "$f" 2>&1)"; then
    echo "$out" | grep -v 'NOTICE' >&2
    echo "✗ $(basename "$f") failed to load"
    exit 1
  fi
done

# Re-running the newest migration must be safe (they say so in their headers).
latest="$(ls "$migrations"/[0-9][0-9][0-9][0-9]_*.sql | tail -1)"
echo "• $(basename "$latest") again (re-run)"
psql_file "$latest" >/dev/null 2>&1 || { echo "✗ $(basename "$latest") is not safe to re-run"; psql_file "$latest"; exit 1; }

status=0
if [[ $# -gt 0 ]]; then
  tests=(); for t in "$@"; do tests+=("$here/${t%_test.sql}_test.sql"); done
else
  tests=("$here"/*_test.sql)
fi
for t in "${tests[@]}"; do
  echo "• test $(basename "$t")"
  # Tests run outside a single transaction: some steps need their own.
  if ! docker exec -i "$name" psql -U postgres -X -q -v ON_ERROR_STOP=1 -f - < "$t"; then
    echo "✗ $(basename "$t") FAILED"
    status=1
  fi
done
[[ $status -eq 0 ]] && echo "✓ all passed"
exit $status
