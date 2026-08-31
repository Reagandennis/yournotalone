# Next steps — Google Sign-In / release 2.2.0

Google Sign-In is **built, tested and working**. Verified on an Android emulator
against the live Supabase project: the account picker opens, a session is
created, and `full_name` / `avatar_url` are backfilled from the Google claims.
`flutter analyze` is clean, all 27 tests pass, and both the Android APK and the
iOS simulator target build.

Everything below is **Play release plumbing**, not feature work.

---

## 1. Blocked: upload key reset ⬜

The original upload keystore was lost. A replacement has been generated at
`~/keystores/yournotalone-upload.jks` (not in this repo — keystores are
gitignored), along with `~/keystores/upload_certificate.pem`.

- [ ] Submit `upload_certificate.pem` via **Play Console → Test and release →
      App integrity → App signing → Request upload key reset**
- [ ] Wait for Google to activate it (typically 1–2 business days)

No release can be uploaded until this lands. The **app signing key is
unchanged**, so users on the live version are completely unaffected.

New upload key SHA-1:

```
41:4E:89:82:6E:B6:CB:E8:AD:3E:D3:3B:3C:F5:C4:5E:01:15:F4:D6
```

- [ ] **Back up the `.jks` off this machine** and put its password in a password
      manager. It was lost once because it sat outside the iCloud-synced folder.

## 2. Local: finish `android/key.properties` ⬜

The file exists at `android/key.properties` (gitignored, never committed) and
already points at the right path with alias `upload`. It still carries the
**old** keystore's password.

- [ ] Replace `storePassword=` and `keyPassword=` with the password chosen when
      generating the new keystore. Leave `storeFile` and `keyAlias` alone.

Verify without exposing the password:

```sh
keytool -list -keystore ~/keystores/yournotalone-upload.jks -alias upload
```

## 3. After the reset is approved ⬜

- [ ] Register `41:4E:89:82:...` as a **new Android OAuth client** in Google
      Cloud project `497109017811`, package `com.techgetafrica.yournotalone`
      (console.cloud.google.com/auth/clients → Create client → Android)
- [ ] Delete the dead client for the retired `71:C4:BD:BE:...` fingerprint

## 4. Cut release 2.2.0 ⬜

- [ ] Set the version in `pubspec.yaml` — currently the stale `1.0.0+2`. It must
      become `2.2.0+<n+1>`, where `n` is the versionCode of the current live
      release (Play Console → Test and release → Releases overview, the number
      in parentheses). Play rejects any upload whose versionCode is not higher
      than every previous one.
- [ ] `flutter build appbundle --release`
- [ ] Confirm the AAB is signed with the **upload** key, not debug:
      `keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`
- [ ] Upload to the **internal testing track first** and sign in with Google
      there. That build carries the real Play app signing key — it is the only
      test that proves production works. A green debug run does not.
- [ ] Promote to production, ideally as a staged rollout

---

## Not yet verified

- **iOS end to end.** It compiles and the reversed-client-ID URL scheme is in
  `ios/Runner/Info.plist`, but nobody has signed in on an iOS device or
  simulator yet.
- **Email/password regression.** A second `<dict>` was appended to the existing
  `CFBundleURLTypes` array rather than replacing it, so the Supabase
  password-reset and email-confirmation deep links should be intact — but that
  is reasoning, not a test. Worth 30 seconds on iOS.
- **Sign-out round trip.** `signOutFromGoogle()` in
  `lib/home/settings_tab.dart` should make the next sign-in show the account
  picker instead of silently reusing the account, and a returning user should
  land on the home shell rather than onboarding.

## Known rough edge

If the Google flow is killed externally mid-sign-in (e.g. Play Services is
force-stopped), `authenticate()` never resolves and both auth buttons stay
disabled until the app restarts. Normal cancellation is handled correctly and
returns cleanly. Only reproducible by artificially killing the process; a
timeout guard would close it if it ever shows up in the wild.

## Reference

Full setup — all five OAuth clients, every SHA-1, the Supabase configuration and
a troubleshooting table — is in [`docs/google-sign-in-setup.md`](docs/google-sign-in-setup.md).
