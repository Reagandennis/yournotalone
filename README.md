# Δεν είσαι μόνος

*"You're not alone"* — a mental-wellness app: daily mood check-ins, journaling,
guided meditation and breathing, calming sounds, addiction-recovery tools, and
video sessions with licensed therapists.

Flutter (Android-first), Supabase for auth and data, RevenueCat for purchases,
LiveKit for therapy calls.

## Running it

```sh
flutter pub get
flutter run
```

The Supabase project is configured in `lib/main.dart`. The database schema lives
in `supabase/migrations/` — run each file once, in order, in the Supabase
dashboard's SQL editor (or `supabase db query --linked -f <file>`). The Edge
Functions must be deployed:

```sh
supabase functions deploy delete-account           # in-app account deletion
supabase functions deploy session-token            # joining a therapy call
supabase functions deploy confirm-session-payment  # paid therapy sessions
supabase functions deploy revenuecat-webhook --no-verify-jwt  # refunds
```

## Therapy sessions

A client pays for and requests a session (the request is a draft until the
$20 purchase is verified, then the care team is emailed and the client gets a
receipt — migration 0019); the care team matches it with a therapist and a
time in the app; both join a video call in the app; afterwards the therapist
leaves a note and each side rates the other. Sessions can be cancelled in the
app up to 24 hours ahead for a refund; a no-show is closed out as missed, not
refunded, and the client is told. `supabase/migrations/0009_therapy_platform.sql`
explains who can see and do what.

- **Admins** are the emails in `public.admins` (see `supabase/therapy_ops.sql`).
  They get **Settings → Care team dashboard** once signed in with that email
  confirmed.
- **Therapists** are added from the dashboard with the email they sign in
  with. They get **Settings → My therapy sessions**.
- **Calls** need Edge Function secrets from LiveKit Cloud → Settings → Keys:

  ```sh
  supabase secrets set LIVEKIT_URL=wss://<project>.livekit.cloud \
    LIVEKIT_API_KEY=<key> LIVEKIT_API_SECRET=<secret>
  ```

- **Payments** ($20 per session, taken before the request is sent) go through
  Paystack (migration 0021): card, M-Pesa / mobile money and Apple Pay, on
  Paystack's page in an in-app browser. `paystack-payment` opens the checkout
  and confirms it with Paystack's verify API; `paystack-webhook` (deployed
  `--no-verify-jwt`, registered as the Paystack webhook URL) records
  `charge.success` and `refund.processed`. Both need `PAYSTACK_SECRET_KEY`;
  `PAYSTACK_CALLBACK_URL` is optional. Sessions are charged in USD, so USD
  must be enabled on the Paystack account. Sessions paid before the switch
  went through the Google Play product `therapy` and `confirm-session-payment`
  (RevenueCat). The care team can also mark a session paid or waive the fee
  from the dashboard.
- **Refunds** (migration 0012) come in through `revenuecat-webhook`, which
  needs `REVENUECAT_WEBHOOK_SECRET` and is registered in RevenueCat →
  Integrations → Webhooks with the Authorization header value
  `Bearer <that secret>`. A refunded session goes back to unpaid, so it can't
  be joined, and the care team and client are emailed. A refund Google later
  reverses (migration 0013) makes the session paid again.
- **Emails** go through Resend (migrations 0008 and 0009), using the Vault
  secrets `resend_api_key` and `resend_from`.
- **Limits** on requests (migration 0011): topic and note sizes are checked
  in the database, a person can have one open request at a time and at most
  5 a day, and the app is refused above 60 requests an hour overall. Each
  refusal carries a message the app shows as is.
- **Phone notifications** use no Firebase or push service (migration 0010).
  Session news — booked, changed, cancelled, reminders — is queued in
  `app_notifications`. The app collects it on launch and, on Android, about
  every 15 minutes in the background with WorkManager, using a random
  per-install key (`lib/notifications/`). Each session's 10-minute reminder is
  also scheduled on the phone, and pg_cron emails both people 10 minutes
  before (`send_session_reminders()`).

## Checks

```sh
flutter analyze
flutter test
```

CI (`.github/workflows/android.yml`) runs both on every push, plus secret and
dependency scanning, and builds a signed AAB for `v*` tags.

## Layout

| Path | What's in it |
|---|---|
| `lib/auth/` | Sign-in, sign-up, password reset, Google sign-in |
| `lib/onboarding/` | Welcome → features → check-in → therapy offer → paywall |
| `lib/home/` | The signed-in shell: home, explore, settings, mood |
| `lib/meditation/`, `lib/sounds/` | Guided sessions, breathing, the sound library |
| `lib/journal/`, `lib/practice/` | Journal and prompts; practice history |
| `lib/recovery/` | Commitments, HALT, urge tools, trigger insights |
| `lib/therapy/` | Requesting, paying for, joining and rating sessions; the call screen |
| `lib/care/` | Care team dashboard, matching, therapists; a therapist's own sessions |
| `lib/notifications/` | Session notifications and reminders, the shared notifications plugin |
| `lib/support/` | FAQ and crisis resources |
| `supabase/` | Migrations, Edge Functions, and day-to-day SQL (`*_ops.sql`) |
| `assets/sounds/` | Loops generated by `scripts/sounds/generate_sounds.py` |
| `docs/` | Legal pages, store listing, release and compliance notes |
