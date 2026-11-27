#!/usr/bin/env bash
# Runs supabase/tests/run.sh on a machine with Docker over SSH (default:
# the ops server), copying only supabase/migrations and supabase/tests
# into a scratch folder there. Faster than DOCKER_HOST=ssh://… because
# every docker call stays on that machine. Nothing touches the live project.
#
#   supabase/tests/run_remote.sh [test names…]
#   TEST_HOST=user@host supabase/tests/run_remote.sh
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
host="${TEST_HOST:-azureuser@reagan-server.tail55bf0e.ts.net}"
dir="/tmp/yna-migration-tests-$$"

COPYFILE_DISABLE=1 tar --no-xattrs -C "$here/.." -czf - migrations tests \
  | ssh "$host" "mkdir -p $dir && tar -C $dir -xzf - && trap 'rm -rf $dir' EXIT && KEEP=${KEEP:-} PG_IMAGE=${PG_IMAGE:-postgres:17-alpine} bash $dir/tests/run.sh $*"
