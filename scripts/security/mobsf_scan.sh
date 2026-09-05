#!/usr/bin/env bash
# Runs a MobSF (Mobile Security Framework) static scan of an APK in Docker and saves JSON/PDF reports.
# Usage: scripts/security/mobsf_scan.sh [path/to/app-release.apk]
# Env:   MOBSF_API_KEY (optional, random if unset) KEEP_MOBSF=1 (leave container running) MOBSF_PORT (default 8000)
#        MOBSF_FAIL_ON=high|warning|none (default high: exit 1 when any HIGH finding)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APK="${1:-$ROOT/build/app/outputs/flutter-apk/app-release.apk}"
OUT="$ROOT/build/security"; mkdir -p "$OUT"
IMAGE="${MOBSF_IMAGE:-opensecurity/mobile-security-framework-mobsf:latest}"
NAME="mobsf-yournotalone"
PORT="${MOBSF_PORT:-8000}"
FAIL_ON="${MOBSF_FAIL_ON:-high}"
API_KEY="${MOBSF_API_KEY:-$(openssl rand -hex 16)}"
BASE="http://127.0.0.1:$PORT"

[ -f "$APK" ] || { echo "APK not found: $APK" >&2; exit 2; }
command -v docker >/dev/null || { echo "docker is required for MobSF" >&2; exit 2; }
docker info >/dev/null 2>&1 || { echo "docker daemon is not running" >&2; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required to summarise the report" >&2; exit 2; }

cleanup() {
  if [ "${KEEP_MOBSF:-0}" != "1" ]; then
    docker rm -f "$NAME" >/dev/null 2>&1 || true
  else
    echo "MobSF left running at $BASE (API key: $API_KEY)"
  fi
}
trap cleanup EXIT

docker rm -f "$NAME" >/dev/null 2>&1 || true
echo "== starting MobSF ($IMAGE) =="
docker run -d --name "$NAME" -p "127.0.0.1:$PORT:8000" -e MOBSF_API_KEY="$API_KEY" "$IMAGE" >/dev/null

for i in $(seq 1 90); do
  if curl -fs -o /dev/null "$BASE/api/v1/scans" -H "Authorization: $API_KEY" 2>/dev/null; then break; fi
  if [ "$i" -eq 90 ]; then echo "MobSF did not become ready" >&2; docker logs "$NAME" | tail -20; exit 3; fi
  sleep 2
done

echo "== uploading $(basename "$APK") =="
UPLOAD=$(curl -fsS -F "file=@$APK" "$BASE/api/v1/upload" -H "Authorization: $API_KEY") || { echo "upload failed" >&2; exit 3; }
HASH=$(printf '%s' "$UPLOAD" | python3 -c 'import sys,json; print(json.load(sys.stdin)["hash"])')
SCAN_TYPE=$(printf '%s' "$UPLOAD" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("scan_type","apk"))')
FILE_NAME=$(printf '%s' "$UPLOAD" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("file_name",""))')

echo "== scanning (this takes a few minutes) =="
curl -fsS -X POST "$BASE/api/v1/scan" -H "Authorization: $API_KEY" \
  --data-urlencode "hash=$HASH" --data-urlencode "scan_type=$SCAN_TYPE" --data-urlencode "file_name=$FILE_NAME" \
  -o "$OUT/mobsf-scan-raw.json" || { echo "scan failed" >&2; exit 3; }

curl -fsS -X POST "$BASE/api/v1/report_json" -H "Authorization: $API_KEY" --data-urlencode "hash=$HASH" -o "$OUT/mobsf-report.json"
curl -fsS -X POST "$BASE/api/v1/scorecard"   -H "Authorization: $API_KEY" --data-urlencode "hash=$HASH" -o "$OUT/mobsf-scorecard.json"
curl -fsS -X POST "$BASE/api/v1/download_pdf" -H "Authorization: $API_KEY" --data-urlencode "hash=$HASH" -o "$OUT/mobsf-report.pdf" || true

python3 - "$OUT/mobsf-scorecard.json" "$OUT/mobsf-report.json" "$OUT/mobsf-summary.md" "$FAIL_ON" <<'PY'
import json, sys
score_path, report_path, out_path, fail_on = sys.argv[1:5]
sc = json.load(open(score_path))
rep = json.load(open(report_path))
lines = []
lines.append(f"# MobSF scan: {rep.get('app_name','?')} {rep.get('version_name','')} ({rep.get('package_name','')})")
lines.append("")
lines.append(f"**Security score:** {sc.get('security_score','?')}/100   "
             f"high={len(sc.get('high',[]))} warning={len(sc.get('warning',[]))} info={len(sc.get('info',[]))} "
             f"secure={len(sc.get('secure',[]))} hotspot={len(sc.get('hotspot',[]))}")
lines.append("")
for level in ("high", "warning", "info", "hotspot"):
    items = sc.get(level, [])
    if not items: continue
    lines.append(f"## {level.upper()} ({len(items)})")
    for it in items:
        title = it.get("title") or it.get("name") or "?"
        desc = (it.get("description") or "").strip().replace("\n", " ")
        lines.append(f"- **{title}** — {desc[:300]}")
    lines.append("")
perms = rep.get("permissions", {}) or {}
danger = [p for p, d in perms.items() if isinstance(d, dict) and d.get("status") == "dangerous"]
if danger:
    lines.append("## Dangerous permissions")
    lines.extend(f"- {p}" for p in danger)
    lines.append("")
trk = rep.get("trackers", {}) or {}
if trk.get("detected_trackers"):
    lines.append(f"## Trackers detected: {trk['detected_trackers']}")
    for t in trk.get("trackers", []):
        lines.append(f"- {t.get('name')} — {t.get('url','')}")
    lines.append("")
open(out_path, "w").write("\n".join(lines))
print("\n".join(lines))
n_high = len(sc.get("high", [])); n_warn = len(sc.get("warning", []))
if fail_on == "high" and n_high: sys.exit(1)
if fail_on == "warning" and (n_high or n_warn): sys.exit(1)
PY
rc=$?
echo
echo "Reports: $OUT/mobsf-summary.md, mobsf-report.json, mobsf-scorecard.json, mobsf-report.pdf"
exit "$rc"
