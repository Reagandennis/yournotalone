# Play Console compliance

Everything the Play Console asks for that isn't code. Keep this current — the
Data safety form and the Health apps declaration are both re-reviewed on
every update that changes what the app collects.

## URLs

Published by `.github/workflows/pages.yml` from `docs/legal/`. One-time setup:
repository **Settings → Pages → Source = GitHub Actions**.

| Console field | URL |
|---|---|
| Privacy policy (App content → Privacy policy) | `https://reagandennis.github.io/yournotalone/privacy-policy.html` |
| Terms (store listing, optional) | `https://reagandennis.github.io/yournotalone/terms-of-service.html` |
| **Account deletion** (Data safety → account deletion) | `https://reagandennis.github.io/yournotalone/delete-account.html` |
| Support email | `reaganprezzo@gmail.com` |

## App access — reviewer credentials

The whole app is behind a Supabase login (`lib/auth/auth_gate.dart`), so a
reviewer cannot see anything without an account. Under **App content → App
access**, choose "All or some functionality is restricted" and provide:

```
Username: play-review@<your domain>
Password: <set one, store it in the password manager, not here>
Notes:    Sign in with the credentials above. Onboarding runs once; tap
          through Welcome → Features → Check-in, then "Continue with Free"
          on the paywall to reach the main app. Premium features are marked
          with a "Premium" badge and open an upgrade sheet.
```

Create that account against production Supabase. To let reviewers see the paid
surfaces without buying, set `premium_comp` on it — see section 4 of
`supabase/account_ops.sql`. (`plan_choice` no longer grants premium while
RevenueCat is live: it is written once at purchase and never cleared, so it
would keep premium alive through a cancellation.)

## Data safety form

Collected, linked to the user, **not** shared with third parties, and all of it
deletable in-app. No data is used for advertising or tracking; there is no
analytics SDK in the build (verified: no Firebase/Crashlytics/Sentry/PostHog in
`pubspec.yaml`).

| Category | Data type | Collected | Required | Purpose |
|---|---|---|---|---|
| Personal info | Name | Yes | Optional | App functionality (greeting, profile) |
| Personal info | Email address | Yes | Required | Account management, sign-in |
| Photos | Profile photo | Yes | Optional | App functionality (avatar) |
| Health & fitness | **Health info** — mood check-ins, journal entries, recovery streaks, craving logs, therapy requests, the therapist's session note, session ratings and flags | Yes | Optional | App functionality |
| Financial info | Purchase history — subscriptions and paid therapy sessions | Yes | Optional | App functionality (entitlement, session payment) — held by RevenueCat + the store |
| Messages | Other in-app messages — rating comments on therapy sessions | Yes | Optional | App functionality |

Not declared, on purpose: **audio and video from therapy calls**. They stream
live between the two participants through LiveKit and are never recorded or
stored, which is Play's ephemeral-processing case. If recording is ever added,
declare Audio and Photos/videos.
| App activity | Practice history (meditations, breathing, sounds) | Yes | Optional | App functionality |

Security practices to declare:
- Data is encrypted in transit (TLS to Supabase).
- Users can request that data be deleted — **and can delete it in-app**
  (`lib/home/settings_tab.dart` → `AccountRepository.deleteAccount`, backed by
  `supabase/functions/delete-account`).
- Row-level security restricts every table to its owner (see
  `supabase/migrations/`).

## Permissions

| Permission | Why |
|---|---|
| `CAMERA` | Therapy video calls; taking a profile photo |
| `RECORD_AUDIO` | Therapy video calls |
| `MODIFY_AUDIO_SETTINGS`, `BLUETOOTH_CONNECT` | Routing call audio to the speaker or a headset |
| `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE` | Keeping a call connected across network changes |

The camera is declared `required="false"`, so phones without one can still
install the app and join a call on audio.

## Notifications and background work

There is no Firebase or other push SDK in the build. On Android, WorkManager
checks for session news about every 15 minutes — only while the person has a
pending or booked session, or is a therapist — and stops otherwise. Each check
sends a random per-install key to Supabase and shows what comes back as local
notifications. Session reminders are scheduled on the phone with
`inexactAllowWhileIdle`, so no exact-alarm permission is requested.

Data safety: the install key is an app-generated identifier used only for app
functionality. It is deleted on sign-out and with the account. If the form asks,
declare it under Device or other IDs.

## Health apps declaration

The app is a **mental-wellness / self-care** app, not a medical device.

- It does not diagnose, treat, or make clinical claims. The in-app medical
  disclaimer is Terms §1 (`lib/legal/legal_content.dart`).
- It brokers video sessions with licensed therapists (`lib/therapy/`,
  `lib/care/`). Play expects this claim to be substantiated: keep evidence of
  each practitioner's licence on file (the therapist profile's "Licence or
  registration" field is what clients see), and be ready to supply it. Do not
  add anyone in the care team dashboard, or describe them as a therapist in the
  listing, unless that evidence exists.
- Calls are not recorded. A therapist can flag a safety concern after a
  session, which emails the care team immediately
  (`rate_therapy_session()` in migration 0009).
- Crisis resources are surfaced in-app with real, dialable numbers
  (`lib/support/crisis_resources.dart`) — required in practice for this
  category, and reachable from Settings, from a low mood check-in, and from the
  recovery and therapy screens.
- Target age is 16+ (Privacy Policy §"Children"). Set the content rating
  questionnaire accordingly.

## Subscriptions

RevenueCat, entitlement `Techgetafrica Pro`. Declare the app as offering
in-app purchases / subscriptions. Note that deleting an account does **not**
cancel a subscription — this is stated on the deletion page.

Paid therapy sessions are a **one-time, consumable** in-app product, `therapy`,
priced at US$20 (`lib/billing/session_payments.dart`). It is in RevenueCat as a
consumable (`prod3c624dcc89`), and the `confirm-session-payment` Edge Function
verifies purchases with RevenueCat API v2 (`REVENUECAT_SECRET_KEY`,
`REVENUECAT_PROJECT_ID`).
Someone's first session is free and needs no purchase.

To let a reviewer see a session without paying: book one for the review account
from Settings → Care team and use **Waive fee**.

## Before each release

- [ ] `flutter analyze` + `flutter test` green (CI enforces this)
- [ ] Screenshots regenerated if any UI in them changed —
      `android/fastlane/metadata/android/en-US/images/` must match `docs/store/`
- [ ] A real changelog written for the build (not the
      "Bug fixes and performance improvements" placeholder)
- [ ] `version:` bumped in `pubspec.yaml`
- [ ] Data safety re-checked if any new field is stored
