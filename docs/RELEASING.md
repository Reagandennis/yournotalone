# Releasing to Google Play with fastlane

Everything lives in `android/fastlane/`. Lanes are run from the `android/` directory.

```bash
bundle install                 # once, from the repo root (installs the pinned fastlane)
cd android
bundle exec fastlane lanes     # list every lane
```

If `bundle` gives you trouble locally, the Homebrew `fastlane` binary works the same way
(`cd android && fastlane internal`). CI always uses `bundle exec`.

## One-time setup

### 1. Upload keystore (signs the App Bundle)

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties` (gitignored):

```properties
storeFile=upload-keystore.jks
storePassword=<store password>
keyAlias=upload
keyPassword=<key password>
```

`android/app/build.gradle.kts` already reads this file. Keep a backup of the `.jks` and
passwords somewhere safe (a password manager); if you lose it you cannot update the app
unless Play App Signing is enabled (it is, by default, for new apps — the keystore above is
then your *upload* key and Google holds the app signing key).

The `build` lane refuses to run without `key.properties` so a debug-signed bundle can never
reach Play by accident.

### 2. Google Play service account (lets fastlane talk to the Play Console)

1. Play Console → **Setup → API access**. Link (or create) a Google Cloud project.
2. In Google Cloud → **IAM & Admin → Service accounts → Create service account**
   (name it e.g. `fastlane-play`). No project roles are needed.
3. Open the service account → **Keys → Add key → JSON**. Download it.
4. Back in Play Console → **Users and permissions → Invite new users**, enter the
   service-account e-mail, and grant it (app-level, for this app only):
   *Release to production, exclude devices, and use Play App Signing*,
   *Release apps to testing tracks*, *Manage testing tracks and edit tester lists*,
   *View app information and download bulk reports*.
5. Save the JSON as `android/play-service-account.json` (gitignored) and create
   `android/fastlane/.env` (gitignored):

   ```
   SUPPLY_JSON_KEY=play-service-account.json
   ```
6. Verify: `cd android && bundle exec fastlane validate_key`

> The very first build of a brand-new app must be uploaded manually in the Play Console
> (Google's API cannot create the app itself). After that, every release can go through
> fastlane. If the app is still unpublished, add `status:draft` to the lane
> (e.g. `fastlane internal status:draft`).

### 3. Google sign-in signing keys

Google sign-in matches the app by package name plus signing-key SHA-1, so **every**
keystore above needs registering against the Android OAuth client — including the Play App
Signing key Google uses to re-sign what it distributes. Skip that last one and sign-in
works in every local and sideloaded build but fails for everyone installing from Play.
See [GOOGLE_SIGN_IN.md](GOOGLE_SIGN_IN.md).

### 4. Store listing (optional)

`android/fastlane/metadata/android/en-US/` holds the title, descriptions, icon, feature
graphic and screenshots (copied from `docs/store/`). Push them with
`bundle exec fastlane metadata`; pull the current listing with `bundle exec fastlane download_metadata`.

## Day-to-day lanes

| Lane | What it does |
|------|--------------|
| `fastlane test` | `flutter analyze` + `flutter test` |
| `fastlane security` | secrets scan, dependency CVEs, static analysis, builds a release APK and audits its manifest/signing/obfuscation, then a MobSF scan in Docker. Reports land in `build/security/`. Options: `mobsf:false`, `skip_build:true`, `allow_debug_signing:true` |
| `fastlane preflight` | `test` + `security` + `build`, no upload |
| `fastlane internal` | bump versionCode (Play's highest + 1), test, build a signed AAB, upload to **Internal testing** |
| `fastlane alpha` / `fastlane beta` | same, to **Closed** / **Open** testing |
| `fastlane production rollout:0.2` | same, to **Production** as a staged rollout (default 10 %) |
| `fastlane promote from:internal to:production rollout:0.1` | promote an existing build without rebuilding |
| `fastlane rollout rollout:1.0` | widen (or complete) the current production rollout |
| `fastlane bump version_name:1.1.0` | edit `pubspec.yaml` version without building |
| `fastlane metadata` | upload listing text + images |

Common options for the release lanes:

```
changelog:"Fixed reminder scheduling"   # release notes (<= 500 chars) written to metadata/.../changelogs/<versionCode>.txt
version_name:1.1.0                      # bump the marketing version too
build_number:12                         # force a versionCode instead of Play max + 1
skip_tests:true  skip_bump:true          # when you already ran them
status:draft                            # for an app that is not yet published
```

Every release lane builds with `--obfuscate --split-debug-info=build/symbols`. Keep the
`build/symbols/` directory for each release if you want readable crash stack traces
(they are also attached as a CI artifact).

## Crash reporting (Sentry)

Crashes and unhandled errors go to Sentry project **techgetafrica-e6 / flutter**
(`lib/main.dart` wraps start-up in `SentryFlutter.init`). Events carry the stack trace,
device, OS and app version and nothing else: `sendDefaultPii` is off and screenshots are
never attached, because a screenshot of this app can show a journal entry or a therapist's
name. Debug builds report with `environment=development`, release builds with `production`;
filter by environment in Sentry to ignore local noise.

What is switched on, all configured in `_configureSentry` in `lib/main.dart`:

| Feature | Setting | Why |
|---|---|---|
| Errors | always | The reason Sentry is here. Start-up is wrapped, so a crash before the first frame is reported too. |
| Logs | `enableLogs`; release builds forward every `debugPrint` line as a `warn` log | The app's `debugPrint` calls are all failure descriptions, most inside catch blocks that otherwise swallow the error. Never user content. |
| Metrics | counters at the funnel points: `auth.sign_in.email` / `auth.sign_in.google` / `auth.sign_up.email`, `mood.logged`, `journal.entry_created`, `practice.completed.<kind>`, `therapy.payment_confirmed`, `therapy.call_joined` | Counts only, no attributes, no identifiers. |
| Session Replay | production: `sessionSampleRate 0`, `onErrorSampleRate 1.0`; development: every session. All text and images masked (`options.privacy`). | A replay of this app is a recording of someone's journal and therapy. Only a session that hit an error is kept, and even that is masked. |
| Tracing | `tracesSampleRate` 0.2 in production, 1.0 in development, `SentryNavigatorObserver` on `MaterialApp` | Only the app-start transaction exists today: the app pushes unnamed `MaterialPageRoute`s, and the observer needs a `RouteSettings(name: …)` to time a screen. Name the routes to get per-screen traces. |

Release builds are obfuscated, so Sentry needs the `--split-debug-info` output to show
readable Dart stack traces. Every release lane (`internal`, `alpha`, `beta`, `production`)
uploads `build/symbols/` after the Play upload by running `dart run sentry_dart_plugin`
(configured in the `sentry:` block of `pubspec.yaml`). It never fails a release: without a
token it prints a warning and the build's crashes will simply be unreadable.

Where the token comes from:

- **Locally**: `sentry.properties` in the project root, created by `sentry-wizard` and
  git-ignored. Re-create it with `auth_token=<token>` if it goes missing (Sentry →
  Settings → Auth Tokens, scopes `project:releases` and `org:read`).
- **CI**: the `SENTRY_AUTH_TOKEN` secret in the `play-store` environment, passed to the
  release lane by `.github/workflows/android.yml`. Add it once in the repository settings.

To upload symbols for a build made outside the lanes, run `dart run sentry_dart_plugin`
from the project root after `flutter build … --obfuscate --split-debug-info=build/symbols`.

## The security suite in detail

Each step is a standalone script in `scripts/security/` so you can run one on its own:

| Script | Tool | Fails when |
|--------|------|-----------|
| `static_analysis.sh` | `flutter analyze --fatal-warnings` | any analyzer warning |
| `secrets_scan.sh` | [gitleaks](https://github.com/gitleaks/gitleaks) over git history *and* the working tree | a secret is found (public client keys are allow-listed in `.gitleaks.toml`) |
| `deps_audit.sh` | [osv-scanner](https://google.github.io/osv-scanner/) on `pubspec.lock`, then `flutter pub outdated` | a dependency has a known CVE |
| `apk_audit.sh <apk>` | `apkanalyzer` + `apksigner` + `strings` | debuggable / cleartext / debug-signed / secret strings in the binary. Warns on backup, exported components, missing obfuscation, targetSdk |
| `mobsf_scan.sh <apk>` | [MobSF](https://github.com/MobSF/Mobile-Security-Framework-MobSF) in Docker (full static analysis, security score, trackers, permissions) | any HIGH finding (`MOBSF_FAIL_ON=warning|none` to change) |

Local prerequisites (macOS): `brew install gitleaks osv-scanner`, Docker Desktop running for MobSF,
Android Studio (for its JDK and `apkanalyzer`).

## GitHub Actions

`.github/workflows/android.yml`:

- **push / pull request** → analyze, tests, secrets scan, CVE scan, release-APK audit.
  Reports are attached as the `security-reports` artifact.
- **tag `v*`** → the above, then a signed AAB is uploaded to the **internal** track.
- **Run workflow** (manual) → pick the track and rollout.

Repository secrets to add (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i android/app/upload-keystore.jks \| pbcopy` |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | full contents of the service-account JSON |

Release flow:

```bash
cd android && bundle exec fastlane bump version_name:1.0.1   # or edit pubspec.yaml
git commit -am "Release 1.0.1" && git tag v1.0.1 && git push --tags
```

CI derives the versionCode from Play, so only the version name needs to be in git.
