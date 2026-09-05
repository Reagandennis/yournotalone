#!/usr/bin/env bash
# Checks Dart/Flutter dependencies against the OSV vulnerability database, then lists outdated packages.
# Exit 1 when a known vulnerability is found.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/build/security"; mkdir -p "$OUT"
cd "$ROOT"

if ! command -v osv-scanner >/dev/null 2>&1; then
  echo "osv-scanner is not installed. macOS: brew install osv-scanner  |  Linux: go install github.com/google/osv-scanner/v2/cmd/osv-scanner@latest" >&2
  exit 2
fi

echo "== osv-scanner: pubspec.lock =="
osv-scanner scan source --lockfile=pubspec.lock --format table 2>&1 | tee "$OUT/osv-pubspec.txt"
rc=${PIPESTATUS[0]}
osv-scanner scan source --lockfile=pubspec.lock --format json --output "$OUT/osv-pubspec.json" >/dev/null 2>&1 || true

# osv-scanner exit codes: 0 clean, 1 vulnerabilities found, 127/128 usage or scan error.
case "$rc" in
  0) echo "✅ No known vulnerabilities in pubspec.lock." ;;
  1) echo "❌ Vulnerable packages found (see above / $OUT/osv-pubspec.json)." >&2 ;;
  *) echo "⚠️  osv-scanner exited with $rc (scan error?)" >&2 ;;
esac

echo
echo "== flutter pub outdated (informational) =="
flutter pub outdated 2>&1 | tee "$OUT/pub-outdated.txt" || true

exit "$rc"
