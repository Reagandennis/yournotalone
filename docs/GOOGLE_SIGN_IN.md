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
   upload key. Copy it from **Play Console → your app → Test and release → Setup → App
   integrity → App signing key certificate → SHA-1**.

Miss #3 and Google sign-in works perfectly in every local build and every internal-track
sideload, then fails for everyone who installs from Play.

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
pick an account, the sheet closes, and the app just sits there with no error — identical to
having dismissed the sheet yourself. Credential Manager throws
`GetCredentialCancellationException` for both, so the app cannot tell them apart and stays
quiet (showing an error every time someone backs out of the sheet would be worse).

**So when Google sign-in "does nothing", read the log.** `GoogleAuth` logs every outcome,
and GMS logs the underlying reason:

```bash
adb logcat | grep -E "Google sign-in ended|Auth.Api.Credentials"
```

| Log line | Cause |
|----------|-------|
| `Unknown error [status=UNREGISTERED_ON_API_CONSOLE]` | **The usual one.** This build's signing SHA-1 is not on the Android OAuth client. Add it (see above). |
| `Google sign-in ended (canceled)` and nothing from GMS | The user really did dismiss the sheet. Working as intended. |
| `…(clientConfigurationError)` / `…(providerConfigurationError)` | Client ID or Play Services problem; the description says which. |
| Supabase returns "Unacceptable audience in id_token" | The platform's client ID is missing from the Supabase provider's Client IDs list. |
| Nonce-related error from Supabase | Something started passing a `nonce` to `initialize()`; either stop, or enable "Skip nonce checks". |

The trap this sets: sign-in works all through development, then the Play build reaches real
users signed with Google's app-signing key, that SHA-1 was never registered, and every one
of them taps the button and sees *nothing at all*. Register the Play App Signing SHA-1
before the first release and check logcat once on a Play-installed build.
