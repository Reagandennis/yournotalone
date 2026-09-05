#!/usr/bin/env bash
# Dart static analysis. Warnings are fatal; infos are reported but not fatal.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/build/security"; mkdir -p "$OUT"
cd "$ROOT"
flutter pub get >/dev/null
flutter analyze --no-fatal-infos --fatal-warnings 2>&1 | tee "$OUT/flutter-analyze.txt"
exit "${PIPESTATUS[0]}"
