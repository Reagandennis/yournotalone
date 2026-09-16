# Sign in with Google

The app signs in with Google natively — the Android system account sheet or the iOS
Google sheet, no browser hop — and trades the resulting Google ID token for a Supabase
session (`signInWithIdToken`). There is no separate sign-up: Supabase creates the user on
their first Google sign-in and matches them by email afterwards, which is why the same
"Continue with Google" button sits on both the login and the signup screen.

Code: `lib/auth/google_auth.dart` (the flow) and `lib/auth/google_button.dart` (the button).

## The three client IDs

All three live in Google Cloud project **497109017811** under
*APIs & Services → Credentials*. They are public identifiers, not secrets — they ship
inside the app binary, so they are committed to this repo deliberately.

| Type | Client ID | Where it is used |
|------|-----------|------------------|
| **Web** | `…-so8kopsij12akf28engc1fu9rfhbp2rm` | `serverClientId` in `google_auth.dart`. Android's ID token carries this as its `aud`. |
| **iOS** | `…-nm4kb8gspio91adb3tudjfbslvinkcjs` | `clientId` on Apple platforms, and reversed into the URL scheme in `ios/Runner/Info.plist`. iOS's ID token carries this as its `aud`. |
| **Android** | `…-4eb9kqc2tpsu3mh84gq0e19rmjjeb6un` | Never appears in code. Android identifies the app by package name + signing-key SHA-1. |

## Supabase configuration

*Authentication → Providers → Google* (project `zpcfavemnvfhqaxqhmri`):

- **Enabled**: on.
- **Client IDs**: must list the **web** and **iOS** IDs, comma-separated — Supabase rejects
  an ID token whose `aud` it does not recognise, and the two platforms send different ones.
  Adding the Android ID too is harmless but does nothing.
- **Client Secret**: only needed for the browser-based OAuth flow, which this app does not
  use. Leave it empty.
- **Skip nonce checks**: leave **off**. The app never passes a nonce, so Google issues
  tokens without a `nonce` claim and Supabase has nothing to check. Only turn it on if a
  future change starts passing one.

The Callback URL shown in the dashboard
(`https://zpcfavemnvfhqaxqhmri.supabase.co/auth/v1/callback`) belongs to the web OAuth
flow and is unused here. Native sign-in never leaves the app.

## Android: register every signing key's SHA-1

This is the step that bites. The Android OAuth client is matched by package name
(`com.techgetafrica.yournotalone`) **plus** the SHA-1 of the certificate the installed APK
was signed with. A SHA-1 that isn't registered fails with a bare
"client configuration error" and no further detail.

Three certificates matter. A Google Cloud **Android OAuth client holds exactly one package
name and one SHA-1** — there is no "add another fingerprint" — so each certificate needs its
*own* Android client under *APIs & Services → Credentials*, all three carrying the same
package name `com.techgetafrica.yournotalone`. Ending up with three Android client IDs is
correct and expected; none of them is referenced from code, so nothing else changes.

(Firebase-based projects hide this — its console takes several SHA-1s per app and quietly
creates one OAuth client behind each. This project has no Firebase, so they are made by hand.)

```bash
# 1. Debug key — for `flutter run` on a dev machine. Each machine has its own.
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore \
  -storepass android -keypass android | grep SHA1

# 2. Upload key — for locally built release APKs / AABs (see RELEASING.md).
keytool -list -v -alias upload -keystore android/app/upload-keystore.jks | grep SHA1
```

3. **Play App Signing key** — the one that matters in production. Google re-signs every
   build it distributes, so what users install is signed with *Google's* key, not the
   upload key. Find it under **Play Console → your app → Protected with Play → App
   signing** (older navigation: Test and release → Setup → App integrity).

   **Read that page carefully.** This app's signing key was upgraded to a "quantum-ready"
   key on 13 Aug 2026, so the page shows *three* certificates: the upgraded key's
   "Classical key" and "Post-quantum cryptography key", plus one row under *Previous app
   signing keys*. Play still ships builds signed with the **previous** key — verified on
   16 Sep 2026 by installing 1.1.0+3 from the internal-testing track on the emulator,
   pulling `base.apk` and running `apksigner verify --print-certs` on it (a single v3
   signer, SHA-1 `A7:71:…:99:E4`). Only the "Classical key" had been registered, which is
   why every Play install failed with the silent "[16] Account reauth failed." while every
   sideloaded upload-key build worked. All three are registered now (16 Sep 2026), each as
   its own Android client, and sign-in on a Play-installed build was verified afterwards.

Miss #3 and Google sign-in works perfectly in every local build and every internal-track
sideload, then fails for everyone who installs from Play.

Certificate fingerprints are public, so the current ones are recorded here to save the hunt —
but Play Console stays authoritative, and these change if a key is ever rotated:

| Certificate | SHA-1 | Registered as |
|---|---|---|
| Play app signing — **previous key, the one Play actually ships** (first used 13 Aug 2026) | `A7:71:97:37:58:3B:C8:90:C6:1E:C7:9D:05:A1:96:3B:42:1F:99:E4` | Android client 4 (created 16 Sep 2026) |
| Play app signing — upgraded "Classical key" | `69:DD:1D:78:72:F0:34:C9:A1:33:11:2F:AB:CE:EB:C1:FA:01:50:E5` | You're Not Alone — Android (Play app signing) |
| Play app signing — "Post-quantum cryptography key" | `D6:20:12:F3:56:4E:1D:6D:D5:60:9C:B2:92:F8:69:09:F7:88:75:F9` | Android client 5 (created 16 Sep 2026) |
| Upload key (current, generated 5 Sep 2026) | `22:05:B7:7E:53:80:14:1D:48:05:21:9D:31:05:42:42:E0:D4:7C:B9` | You're Not Alone — Android (upload key) |
| ~~Upload key (original, lost — reset via Play 5 Sep 2026)~~ | ~~`71:C4:BD:BE:77:FE:73:EA:5C:D2:CC:B3:F1:B7:77:44:C0:9E:9E:A2`~~ | — |
| Debug (this machine, created 3 Sep 2026) | `EE:6A:09:F1:CA:B1:AF:FB:0F:9F:4E:17:A5:31:B1:71:26:FA:38:E3` | You're Not Alone — Android |

To learn what Play really ships, don't trust the console — check an installed copy. Install
from Play on the emulator (its Google account is an internal tester), then:

```bash
adb shell pm path com.techgetafrica.yournotalone
adb pull /data/app/…/base.apk /tmp/play-base.apk
$ANDROID_HOME/build-tools/36.0.0/apksigner verify --print-certs /tmp/play-base.apk
```

A debug keystore is regenerated silently by Android Studio whenever it goes missing or
expires, and the replacement has a different fingerprint — which is exactly how this first
broke. Re-check the debug row against `keytool` before assuming the code is at fault.

## iOS

`ios/Runner/Info.plist` already registers the reversed iOS client ID
(`com.googleusercontent.apps.497109017811-nm4kb8gspio91adb3tudjfbslvinkcjs`) as a URL
scheme, alongside the existing `com.techgetafrica.yournotalone` scheme used by the auth
emails. The client ID itself is passed from `google_auth.dart`, so no `GIDClientID` key is
needed. iOS needs no SHA-1 equivalent — the bundle ID is the identifier.

Deployment target is 13.0, which is what `google_sign_in_ios` requires.

## What a Google user's profile looks like

Supabase fills `user_metadata` from Google's ID token: `full_name`, `avatar_url`,
`picture`, `email`. The app already reads `full_name` and `avatar_url` (home greeting,
settings, onboarding), so a Google user's name and photo appear with no extra work, and
`onboarding_complete` is absent on a new account so they land in onboarding like anyone
else.

One consequence worth knowing: Supabase re-applies Google's identity data to
`user_metadata` on *every* Google sign-in. A user who signs in with Google and then sets a
custom photo in *Edit profile* — which writes `avatar_url` into the same metadata — may see
it revert to their Google picture next time they sign in. Moving profile fields to a
`profiles` table would settle it if that turns out to matter.

## Troubleshooting

**Android reports a botched configuration as a cancellation.** The account sheet opens, you
pick an account, the sheet closes, and the app is back on the form — from the outside,
identical to having dismissed the sheet yourself. Credential Manager throws
`GetCredentialCancellationException` for both. They differ only in the exception's
description, which `GoogleAuth._isDismissal` checks: a description that mentions cancelling
is a real dismissal and stays quiet; anything else is shown on screen as "Google couldn't
finish signing you in…" with the raw description in brackets, so a tester on a phone nobody
can plug into adb can read the reason back to you.

Verified on the emulator on 16 Sep 2026 by re-signing the release APK with a throwaway
keystore whose SHA-1 is registered nowhere:

| What the app receives | What GMS logs (`Auth.Api.Credentials`) | Meaning |
|---|---|---|
| `canceled`: `[16] Cancelled by user.` | `GoogleSignIn_flowRunner Flow failed`, nothing else | The user really did back out. Working as intended; nothing shown. |
| `canceled`: `[16] Account reauth failed.` | `[8] Unknown error [status=UNREGISTERED_ON_API_CONSOLE]` | **The usual one.** This build's signing SHA-1 is not on any Android OAuth client. Add it (see above). Shown on screen. |

**With adb, read the log.** `GoogleAuth` logs every outcome, and GMS logs the underlying
reason:

```bash
adb logcat | grep -E "Google sign-in ended|Auth.Api.Credentials"
```

| Log line | Cause |
|----------|-------|
| `Unknown error [status=UNREGISTERED_ON_API_CONSOLE]` | SHA-1 not registered, as above. |
| `…(clientConfigurationError)` / `…(providerConfigurationError)` | Client ID or Play Services problem; the description says which. |
| Supabase returns "Unacceptable audience in id_token" | The platform's client ID is missing from the Supabase provider's Client IDs list. |
| Nonce-related error from Supabase | Something started passing a `nonce` to `initialize()`; either stop, or enable "Skip nonce checks". |

**Works on the emulator, fails on other people's phones.** Two things differ: the signing
key (a Play install is signed with Google's app-signing key, not the upload key) and the
Google account. If the OAuth consent screen is still in *Testing*, only the listed test
users can sign in and everyone else fails at the same silent point — publish it (the basic
scopes used here need no review) or add the tester's address under test users.

**To reproduce a broken key locally**, sign a copy of the release APK with a fresh keystore
and install that on the emulator:

```bash
keytool -genkeypair -keystore /tmp/bogus.jks -alias bogus -keyalg RSA \
  -storepass bogus123 -keypass bogus123 -dname "CN=Unregistered"
cp build/app/outputs/flutter-apk/app-release.apk /tmp/app-bogus.apk
$ANDROID_HOME/build-tools/36.0.0/apksigner sign --ks /tmp/bogus.jks \
  --ks-key-alias bogus --ks-pass pass:bogus123 /tmp/app-bogus.apk
```

The trap this sets: sign-in works all through development, then the Play build reaches real
users signed with Google's app-signing key, that SHA-1 was never registered, and every one
of them taps the button and gets a one-line error. Register the Play App Signing SHA-1
before the first release and check once on a Play-installed build.
