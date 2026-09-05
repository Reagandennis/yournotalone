#!/usr/bin/env bash
# Scans git history AND the working tree (incl. untracked files) for leaked secrets with gitleaks.
# Exit 1 when leaks are found. Tune false positives in .gitleaks.toml.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/build/security"; mkdir -p "$OUT"
cd "$ROOT"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "gitleaks is not installed. macOS: brew install gitleaks  |  Linux: https://github.com/gitleaks/gitleaks/releases" >&2
  exit 2
fi

CFG=()
[ -f .gitleaks.toml ] && CFG=(--config .gitleaks.toml)

status=0
echo "== gitleaks: git history =="
gitleaks git "${CFG[@]}" --redact=60 --exit-code 1 \
  --report-format json --report-path "$OUT/gitleaks-history.json" . || status=1

echo "== gitleaks: working tree (tracked + untracked) =="
gitleaks dir "${CFG[@]}" --redact=60 --exit-code 1 \
  --report-format json --report-path "$OUT/gitleaks-worktree.json" . || status=1

if [ "$status" -ne 0 ]; then
  echo
  echo "❌ Secrets detected. Reports: $OUT/gitleaks-*.json" >&2
  echo "   If a hit is a public client key, allow-list it in .gitleaks.toml with a comment explaining why." >&2
else
  echo "✅ No secrets found."
fi
exit "$status"
