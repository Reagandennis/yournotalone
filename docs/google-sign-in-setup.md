# Google Sign-In setup

The app uses **native** Google sign-in: `google_sign_in` obtains an ID token,
and that token is exchanged for a Supabase session via `signInWithIdToken`.
The browser-redirect flow is not used.

All the code lives in [`lib/auth/google_auth.dart`](../lib/auth/google_auth.dart).

## 1. Google Cloud console — three OAuth clients

Create all three in the **same** Google Cloud project, and configure the OAuth
consent screen (app name, support email, developer email). While consent is in
*Testing* status, only listed test users can sign in.

Google Cloud project number: **497109017811**.

| Type | Fields | Where it's used | Status |
|---|---|---|---|
| **Android** | Package `com.techgetafrica.yournotalone` + signing SHA-1 | Never referenced in code. Authorizes the app signature. | ✅ debug; see the per-certificate table below — **three** clients are needed |
| **Web application** | Name only | `serverClientId` in `google_auth.dart`, and Supabase → Client IDs. This is the token audience. | ✅ `497109017811-so8kopsij12akf28engc1fu9rfhbp2rm` |
| **iOS** | Bundle ID `com.techgetafrica.yournotalone` | `clientId` in `google_auth.dart`, and its reversed form is a URL scheme in `ios/Runner/Info.plist`. | ✅ `497109017811-nm4kb8gspio91adb3tudjfbslvinkcjs` |

Only the **Web** and **iOS** IDs get pasted into the app. The Android client ID is
recorded here for reference only — it is deliberately absent from the codebase.

### Android OAuth clients — one per signing certificate

A Google Cloud Android OAuth client holds exactly **one** package + **one**
SHA-1. You cannot add a second fingerprint to an existing client; you create
another client. They cost nothing and are never named in code.

All use package `com.techgetafrica.yournotalone`:

| SHA-1 | Certificate | Covers | Client ID |
|---|---|---|---|
| `04:3B:42:69:7F:48:34:33:3F:CB:E4:F2:DD:F6:36:A3:48:63:46:65` | debug keystore | local `flutter run` / debug builds | `...-t7mqa3q1pt7lu4b385p09qru0lqmpscm` |
| `69:DD:1D:78:72:F0:34:C9:A1:33:11:2F:AB:CE:EB:C1:FA:01:50:E5` | Play **app signing** key | **every install from the Play Store** | `...-4eb9kqc2tpsu3mh84gq0e19rmjjeb6un` |
| ~~`71:C4:BD:BE:77:FE:73:EA:5C:D2:CC:B3:F1:B7:77:44:C0:9E:9E:A2`~~ | Play upload key (**retired** — keystore lost 2026-08-31) | none; delete this client once the reset lands | `...-mreqnu34sdvdi03ltnrf1ebqckie2tu1` |
| `41:4E:89:82:6E:B6:CB:E8:AD:3E:D3:3B:3C:F5:C4:5E:01:15:F4:D6` | Play **upload** key (new, `~/keystores/yournotalone-upload.jks`) | uploads to Play — ⬜ **pending upload key reset approval**, then register as an OAuth client | ⬜ to create |

All client IDs are prefixed `497109017811-`. The Android client IDs are recorded
here for traceability only — none of them appear in the codebase.

The app signing entry is the one that matters in production. Play re-signs each
upload with the app signing key, so that is the certificate on every installed
copy. Register it or sign-in fails for all Play users while still working
perfectly in debug.

The "Post-quantum cryptography key" fingerprints shown on the same Play Console
page are **not** used for OAuth client registration — do not register those.

Both Play fingerprints come from Play Console → Test and release → App integrity
→ Play app signing (also reachable via Protected with Play → Play Store
protection → Manage Play app signing).

### Getting the Android SHA-1

```sh
keytool -keystore ~/.android/debug.keystore -list -v \
        -alias androiddebugkey -storepass android -keypass android
```

Debug keystore SHA-1 on the current dev machine:

```
04:3B:42:69:7F:48:34:33:3F:CB:E4:F2:DD:F6:36:A3:48:63:46:65
```

### Upload key reset (2026-08-31)

The original upload keystore was lost — it lived outside the iCloud-synced
Desktop folder, so only `key.properties` survived (pointing at a stale
`/Users/reaganenochowiti/...` path). A replacement was generated:

```sh
keytool -genkeypair -v -keystore ~/keystores/yournotalone-upload.jks \
        -keyalg RSA -keysize 2048 -validity 10000 -alias upload
keytool -export -rfc -keystore ~/keystores/yournotalone-upload.jks \
        -alias upload -file ~/keystores/upload_certificate.pem
```

`upload_certificate.pem` was submitted via Play Console → App integrity →
App signing → Request upload key reset. **No release can be uploaded until
Google activates it.** The app signing key is unchanged, so live users are
unaffected.

Read a keystore's SHA-1 without its password, straight from the exported cert:

```sh
openssl x509 -in ~/keystores/upload_certificate.pem -noout -fingerprint -sha1
```

Back up the `.jks` off-machine and store its password in a password manager.

### ⚠️ Release builds need `key.properties`

`android/app/build.gradle.kts` falls back to the **debug** signing config when
`android/key.properties` is absent. That file and the upload keystore are both
gitignored, so they must be present on any machine cutting a release — otherwise
the build is debug-signed and Play rejects the upload.

## 2. Supabase dashboard

**Authentication → Providers → Google**:

1. Enable the provider.
2. Leave the OAuth client ID/secret fields empty (they are for the web redirect flow).
3. **Authorized Client IDs** — the **Web** and **iOS** client IDs, comma-separated.
   Not the Android one; it never appears in a token.
4. Enable **Skip nonce check**. `google_sign_in` v7 only accepts a nonce at global
   `initialize()` time, not per sign-in, so per-request nonce validation is not
   practical.

No SQL migration is needed. There is no `profiles` table — the app keeps
`full_name`, `avatar_url` and `onboarding_complete` in `auth.users.user_metadata`,
and `postAuthDestination()` routes users without `onboarding_complete` into
onboarding, so a new Google user reaches the welcome flow automatically.

## 3. App wiring — already done

`lib/auth/google_auth.dart` carries the Web and iOS client IDs, and
`ios/Runner/Info.plist` carries the reversed iOS client ID as a second URL
scheme. The existing `com.techgetafrica.yournotalone` scheme must stay — the
password-reset and email-confirmation deep links depend on it.

To swap in a different Google Cloud project later, change those two constants
and the Info.plist scheme (the iOS client ID with its dot-separated parts
reversed: `123456-abc.apps.googleusercontent.com` →
`com.googleusercontent.apps.123456-abc`).

Android needs no configuration: no `google-services.json`, no Firebase, no
Gradle plugin. Passing `serverClientId` from Dart is sufficient.

## 4. Testing

The Android emulator must have Play Services (`PlayStore.enabled=true` in the
AVD config) **and a Google account signed in** under
Settings → Passwords & accounts. That account must be a listed test user while
the consent screen is in Testing.

The iOS Simulator works without extra setup — `google_sign_in_ios` uses
`ASWebAuthenticationSession`.

### Troubleshooting

| Symptom | Cause |
|---|---|
| `serverClientId must be provided on Android` | `_webClientId` is still the placeholder |
| Picker opens, then `DEVELOPER_ERROR` / code 10 | SHA-1 or package name mismatch on the Android client |
| Sign-in succeeds but Supabase rejects the token | Web client ID missing from Supabase → Authorized Client IDs |
| `Invalid nonce` | "Skip nonce check" not enabled in Supabase |
| Works in debug, fails from Play Store | Play App Signing SHA-1 not registered |
