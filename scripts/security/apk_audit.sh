#!/usr/bin/env bash
# Audits a built APK the way a reviewer would: manifest hardening flags, exported components,
# permissions, signing certificate, Dart obfuscation, and secrets embedded in the binary.
# Usage: scripts/security/apk_audit.sh [path/to/app-release.apk]
# Env:   EXPECT_RELEASE_SIGNING=1 (default) fails when the APK is debug-signed.
#        ANDROID_HOME / ANDROID_SDK_ROOT to locate apkanalyzer + apksigner.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APK="${1:-$ROOT/build/app/outputs/flutter-apk/app-release.apk}"
OUT="$ROOT/build/security"; mkdir -p "$OUT"
REPORT="$OUT/apk-audit.md"
EXPECT_RELEASE_SIGNING="${EXPECT_RELEASE_SIGNING:-1}"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"

[ -f "$APK" ] || { echo "APK not found: $APK (run: flutter build apk --release)" >&2; exit 2; }

if [ -z "${JAVA_HOME:-}" ] && [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi
[ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"

APKANALYZER=""
for c in "$SDK/cmdline-tools/latest/bin/apkanalyzer" "$SDK/cmdline-tools/bin/apkanalyzer" "$SDK/tools/bin/apkanalyzer" "$(command -v apkanalyzer || true)"; do
  [ -n "$c" ] && [ -x "$c" ] && APKANALYZER="$c" && break
done
APKSIGNER="$(ls "$SDK"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)"
[ -n "$APKANALYZER" ] || { echo "apkanalyzer not found under $SDK (install Android cmdline-tools)" >&2; exit 2; }
[ -n "$APKSIGNER" ] || { echo "apksigner not found under $SDK/build-tools" >&2; exit 2; }

PASS=0; WARN=0; FAIL=0
: > "$REPORT"
say()  { echo "$*" | tee -a "$REPORT"; }
pass() { PASS=$((PASS+1)); say "- ✅ PASS  $*"; }
warn() { WARN=$((WARN+1)); say "- ⚠️  WARN  $*"; }
fail() { FAIL=$((FAIL+1)); say "- ❌ FAIL  $*"; }

say "# APK audit: $(basename "$APK")"
say ""
say "APK: \`$APK\`  ($(du -h "$APK" | cut -f1))"
say ""

# ---------------------------------------------------------------- manifest
MANIFEST="$OUT/apk-manifest.xml"
"$APKANALYZER" manifest print "$APK" > "$MANIFEST" 2>/dev/null || { echo "apkanalyzer failed to read the manifest" >&2; exit 2; }
MIN_SDK=$("$APKANALYZER" manifest min-sdk "$APK" 2>/dev/null || echo "?")
TARGET_SDK=$("$APKANALYZER" manifest target-sdk "$APK" 2>/dev/null || echo "?")
VCODE=$("$APKANALYZER" manifest version-code "$APK" 2>/dev/null || echo "?")
VNAME=$("$APKANALYZER" manifest version-name "$APK" 2>/dev/null || echo "?")
APPID=$("$APKANALYZER" manifest application-id "$APK" 2>/dev/null || echo "?")
say "## Identity"
say ""
say "- applicationId: \`$APPID\`  version: $VNAME ($VCODE)  minSdk: $MIN_SDK  targetSdk: $TARGET_SDK"
say ""
say "## Manifest hardening"
say ""

python3 - "$MANIFEST" "$MIN_SDK" "$TARGET_SDK" > "$OUT/apk-manifest-checks.txt" <<'PY'
import sys, xml.etree.ElementTree as ET
manifest, min_sdk, target_sdk = sys.argv[1], sys.argv[2], sys.argv[3]
A = "{http://schemas.android.com/apk/res/android}"
root = ET.parse(manifest).getroot()
app = root.find("application")
g = lambda el, k: (el.get(A + k) if el is not None else None)
out = []
def emit(kind, msg): out.append(f"{kind}\t{msg}")

# debuggable
emit("FAIL" if g(app, "debuggable") == "true" else "PASS", "android:debuggable is " + (g(app, "debuggable") or "unset (false)"))
# backup
ab = g(app, "allowBackup")
if ab == "false":
    emit("PASS", "android:allowBackup=false (local data is not exposed via adb backup / auto-backup)")
else:
    rules = g(app, "dataExtractionRules") or g(app, "fullBackupContent")
    emit("WARN", f"android:allowBackup is {ab or 'unset (defaults to true)'}"
                 + (f" but backup rules are set ({rules})" if rules else
                    " and no dataExtractionRules/fullBackupContent — shared_preferences (incl. any cached journal/mood state) can be extracted with `adb backup` on older devices and is included in cloud auto-backup. Set android:allowBackup=\"false\" in android/app/src/main/AndroidManifest.xml"))
# cleartext
ct = g(app, "usesCleartextTraffic")
nsc = g(app, "networkSecurityConfig")
if ct == "true":
    emit("FAIL", "android:usesCleartextTraffic=true — plain-HTTP allowed app-wide")
elif nsc:
    emit("PASS", f"networkSecurityConfig present ({nsc})")
else:
    try:
        allowed_by_default = int(min_sdk) < 28
    except ValueError:
        allowed_by_default = True
    if allowed_by_default:
        emit("WARN", f"minSdk {min_sdk} < 28 and no networkSecurityConfig: cleartext HTTP is permitted by default. Add res/xml/network_security_config.xml with cleartextTrafficPermitted=\"false\" (Supabase/RevenueCat are HTTPS-only so nothing breaks)")
    else:
        emit("PASS", "cleartext traffic blocked by platform default (minSdk >= 28)")
# testOnly / extractNativeLibs
if g(app, "testOnly") == "true": emit("FAIL", "android:testOnly=true — Play will reject")
# exported components
comps = []
for tag in ("activity", "activity-alias", "service", "receiver", "provider"):
    for c in app.iter(tag):
        name = g(c, "name")
        exported = g(c, "exported")
        has_filter = c.find("intent-filter") is not None
        perm = g(c, "permission")
        is_launcher = any(cat.get(A + "name") == "android.intent.category.LAUNCHER" for f in c.findall("intent-filter") for cat in f.findall("category"))
        eff = exported == "true" or (exported is None and has_filter)
        if eff:
            schemes = sorted({d.get(A + "scheme") for f in c.findall("intent-filter") for d in f.findall("data") if d.get(A + "scheme")})
            comps.append((tag, name, is_launcher, perm, schemes))
for tag, name, launcher, perm, schemes in comps:
    if launcher and not schemes:
        emit("PASS", f"exported {tag} {name} is the launcher only")
    elif launcher and schemes:
        emit("INFO", f"exported {tag} {name} handles custom scheme(s) {schemes}: any app can register the same scheme; make sure auth links only carry PKCE codes, never tokens, or move to https App Links (autoVerify)")
    elif perm:
        emit("PASS", f"exported {tag} {name} is protected by permission {perm}")
    else:
        emit("WARN", f"exported {tag} {name} has no permission — verify it must be reachable by other apps")
# permissions
perms = [p.get(A + "name") for p in root.findall("uses-permission")] + [p.get(A + "name") for p in root.findall("uses-permission-sdk-23")]
dangerous = {"android.permission.CAMERA","android.permission.RECORD_AUDIO","android.permission.READ_CONTACTS","android.permission.WRITE_CONTACTS",
             "android.permission.ACCESS_FINE_LOCATION","android.permission.ACCESS_COARSE_LOCATION","android.permission.ACCESS_BACKGROUND_LOCATION",
             "android.permission.READ_EXTERNAL_STORAGE","android.permission.WRITE_EXTERNAL_STORAGE","android.permission.READ_MEDIA_IMAGES",
             "android.permission.READ_MEDIA_VIDEO","android.permission.READ_MEDIA_AUDIO","android.permission.READ_PHONE_STATE","android.permission.READ_SMS",
             "android.permission.SEND_SMS","android.permission.READ_CALL_LOG","android.permission.BODY_SENSORS","android.permission.ACTIVITY_RECOGNITION",
             "android.permission.POST_NOTIFICATIONS","android.permission.READ_CALENDAR","android.permission.WRITE_CALENDAR","android.permission.GET_ACCOUNTS"}
risky = {"android.permission.SYSTEM_ALERT_WINDOW","android.permission.REQUEST_INSTALL_PACKAGES","android.permission.MANAGE_EXTERNAL_STORAGE",
         "android.permission.QUERY_ALL_PACKAGES","android.permission.BIND_ACCESSIBILITY_SERVICE","android.permission.READ_LOGS"}
emit("INFO", "permissions: " + (", ".join(p.replace("android.permission.", "") for p in perms) or "none"))
for p in perms:
    if p in risky: emit("WARN", f"{p} requires a Play policy declaration and is a review red flag — drop it unless essential")
d = [p.replace("android.permission.", "") for p in perms if p in dangerous]
if d: emit("INFO", "runtime (dangerous) permissions that must be requested in-app and declared in Data safety: " + ", ".join(d))
# target sdk
try:
    if int(target_sdk) < 35: emit("WARN", f"targetSdk {target_sdk} < 35 — Google Play requires API 35+ for new releases")
    else: emit("PASS", f"targetSdk {target_sdk} meets Play's requirement")
except ValueError: pass
print("\n".join(out))
PY
while IFS=$'\t' read -r kind msg; do
  case "$kind" in
    PASS) pass "$msg";; WARN) warn "$msg";; FAIL) fail "$msg";; INFO) say "- ℹ️  INFO  $msg";;
  esac
done < "$OUT/apk-manifest-checks.txt"

# ---------------------------------------------------------------- signing
say ""
say "## Signing"
say ""
SIG="$OUT/apk-signature.txt"
"$APKSIGNER" verify --print-certs -v "$APK" > "$SIG" 2>&1 || true
if grep -q "Android Debug" "$SIG"; then
  if [ "$EXPECT_RELEASE_SIGNING" = "1" ]; then
    fail "APK is signed with the DEBUG keystore (CN=Android Debug). android/key.properties is missing or wrong — Play will reject this upload"
  else
    warn "APK is signed with the DEBUG keystore (expected: no android/key.properties on this machine)"
  fi
else
  DN=$(grep -m1 "certificate DN" "$SIG" | sed 's/^.*DN: //')
  pass "release signing certificate: ${DN:-unknown}"
fi
grep -qE "v2 scheme.*: true|v3 scheme.*: true" "$SIG" && pass "APK Signature Scheme v2/v3 present" || warn "no v2/v3 signature scheme detected (v1-only signatures are weak)"
# Ignore JDK 24+ "restricted method / native access" chatter, which is about the JVM, not the APK.
grep "WARNING" "$SIG" | grep -qvE "restricted method|Restricted methods|native.access|loadLibrary" && warn "apksigner reported warnings — see $SIG"

# ---------------------------------------------------------------- native libs, obfuscation, secrets
say ""
say "## Binary"
say ""
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
unzip -o -q "$APK" 'lib/*/libapp.so' 'classes*.dex' 'assets/flutter_assets/*' -d "$TMP" 2>/dev/null || true
LIBAPP="$(ls "$TMP"/lib/*/libapp.so 2>/dev/null | head -1)"
if [ -n "$LIBAPP" ]; then
  # These identifiers only survive in libapp.so when the build was NOT made with --obfuscate.
  HITS=$(strings "$LIBAPP" | grep -cE "PurchasesService|JournalRepository|MoodRepository|AuthGate" || true)
  if [ "$HITS" -gt 0 ]; then
    warn "Dart AOT snapshot is not obfuscated ($HITS class names visible). Build with: flutter build appbundle --obfuscate --split-debug-info=build/symbols"
  else
    pass "Dart AOT snapshot appears obfuscated"
  fi
  SECRETS=$( { strings "$LIBAPP"; for d in "$TMP"/classes*.dex; do [ -f "$d" ] && strings "$d"; done; } \
    | grep -oE "service_role|sb_secret_[A-Za-z0-9_]+|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|sk_live_[0-9a-zA-Z]{10,}|ghp_[0-9A-Za-z]{30,}|AIza[0-9A-Za-z_-]{30,}" \
    | sort -u || true)
  if [ -n "$SECRETS" ]; then
    fail "secret-looking strings inside the binary: $(echo "$SECRETS" | tr '\n' ' ')"
  else
    pass "no service-role / private-key / cloud-secret patterns in libapp.so or dex"
  fi
  PUBKEYS=$(strings "$LIBAPP" | grep -oE "sb_publishable_[A-Za-z0-9_]+|goog_[A-Za-z0-9]{20,}|test_[A-Za-z0-9]{20,}" | sort -u | tr '\n' ' ')
  [ -n "$PUBKEYS" ] && say "- ℹ️  INFO  public client keys shipped (expected): $PUBKEYS"
else
  warn "libapp.so not found in APK (not a release AOT build?)"
fi
ABIS=$(unzip -l "$APK" | grep -oE "lib/[a-z0-9_-]+/" | sort -u | tr '\n' ' ')
say "- ℹ️  INFO  native ABIs: ${ABIS:-none}"

# ---------------------------------------------------------------- summary
say ""
say "## Summary"
say ""
say "PASS $PASS · WARN $WARN · FAIL $FAIL"
say ""
say "Full manifest: \`$MANIFEST\` · signature: \`$SIG\`"
[ "$FAIL" -eq 0 ] || exit 1
