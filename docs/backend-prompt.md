# Prompt: content + recommendations backend for yournotalone (Cloudflare)

You are working in the `yournotalone` repo: a Flutter mental-wellness app
(Greek and English, Android first, iOS in review). Read these before you plan anything:

- `lib/discover/content_index.dart`: the single list of everything the app
  offers, with the `Need` and `DayPart` enums.
- `lib/discover/content_tags.dart`: hand-written tags keyed `kind:Title`.
- `lib/discover/usage_store.dart`, `saved_store.dart`, `goals.dart`: the
  on-device signals that drive Home and Explore today.
- The catalogues (`lib/meditation`, `lib/sleep`, `lib/stress`, `lib/cbt`,
  `lib/sounds`, `lib/courses`, `lib/toolkit`) and `lib/sounds/sound_player.dart`
  (just_audio + just_audio_background, which currently plays bundled assets only).
- `supabase/migrations` (especially 0007 practice sessions, 0014 premium flag in
  `app_metadata`, 0024 session feelings) and `supabase/functions`.
- `Sounds/` (about 196 MB of raw WAV/AIFF/MP3) and `assets/sounds`, `assets/narration`.

## Goal

Move content and recommendations off the app binary and onto a backend that
is fast everywhere, so that:

1. New meditations, sounds, courses, lessons and animated backgrounds ship
   without an app release.
2. Tagging and recommendations get better than the hard-coded tables.
3. Audio streams well on slow mobile networks (Kenya and Greece are the
   first markets).
4. A core set of content works fully offline, and users can download more.

Scope for now is **audio, text and animated backgrounds**. Video comes later,
so design the media model so a video kind can be added without a rewrite,
but don't build video support.

## Constraints

- **Cost: stay on Cloudflare's free plan for as long as possible.** It must
  also scale without a redesign when the app grows. Before designing, check
  Cloudflare's current free-tier limits for Workers, D1, KV, R2, Queues and
  Cron Triggers. Don't trust remembered numbers; they change. Write in the
  design doc which limit we hit first, at roughly how many users, and what
  that would cost on the $5 Workers Paid plan.
- Don't use anything that needs a paid plan from day one (for example
  Cloudflare Containers) unless you've shown there's no free alternative.
- One person (me) runs this, so prefer few moving parts over clever ones.

## What already exists (keep it)

Supabase stays the system of record for auth, profiles, journal and moods,
therapy, payments (Paystack, RevenueCat webhooks) and the premium flag. Do not
migrate those. The new backend reads the Supabase JWT to identify users and
check premium.

## Cloudflare resources

- R2 bucket `yournotalone`, location Western Europe (WEUR).
  S3 endpoint `https://f7e65097ea4facdba994ee51d751705a.r2.cloudflarestorage.com/yournotalone`.
- Public custom domain `database.techgetafrica.com` (TLS 1.3 minimum) is
  attached to this bucket. Keep using it. Anything in this bucket can be
  read by anyone who knows the object key, so treat the bucket as **public**
  (see "Security").
- Keep credentials (R2 access keys, Supabase JWT secret, API tokens) in
  Wrangler secrets or env vars. Never put them in code or the app.

## Architecture (follow this unless you find a concrete reason not to, and say why)

The language is open. Pick what runs best on Cloudflare's free tier, which
in practice means a **TypeScript Worker** (Hono or plain fetch handlers).
Use Go or anything else only for local tooling where it helps.

- **R2 `yournotalone` (public, on `database.techgetafrica.com`):** free
  audio, artwork, animated backgrounds and the published catalogue snapshot.
  These are served straight from the CDN cache and never touch the Worker,
  so they cost no Worker requests.
- **A second, private R2 bucket** for premium audio. The Worker checks the
  user's Supabase JWT and premium status, then returns a short-lived
  presigned URL. The app streams directly from that URL, so the Worker is hit
  once per play, not once per byte range. Compare this with serving premium
  media through the Worker and the Cache API, and pick one.
- **D1** for content metadata, tags, collections and recommendation features.
  Set the location hint or jurisdiction to the EU.
- **KV or the Cache API** for precomputed recommendation lists and the
  catalogue version, so reads are cheap.
- **Cron Triggers** for nightly recommendation rebuilds.
- **Heavy media work (transcoding, loudness analysis) runs locally** with a
  script plus ffmpeg on my Mac, and the script uploads the results to R2.
  No cloud compute is needed for this at our size.

## Features

### 1. Content catalogue API

- Schema covering every kind in `content_index.dart`: breathing, meditation,
  sleep story, sound, CBT and stress lessons, courses with ordered steps,
  toolkit items and journal prompts. Add a `background` kind for animated
  backgrounds. Fields: id, kind, title and body per locale (el, en),
  duration, free or premium, needs, day parts, `addedOn`, artwork, media
  renditions, narrator, version, status (draft, published, retired). Items
  can name a default background.
- Publishing writes a versioned JSON snapshot to the public bucket, so the
  CDN serves the catalogue for free. The app checks a small `version` file
  (or uses ETag) and downloads the full snapshot only when it has changed.
- Stable ids replace the `kind:Title` keys. Write a one-time migration that
  exports the current Dart catalogues and tags into the new schema, so nothing
  is lost.

### 2. Animated backgrounds

- Compare Rive, Lottie, and short looping video (for example a few-second
  H.264/HEVC loop) for battery use, file size, smoothness on low-end Android
  phones, and how easy each is to make. Recommend one format. The app already
  draws some art in code (see `lib/toolkit` and `lib/rhythm`), so keep that
  option.
- Backgrounds should be small, cached once, and usable offline. They must
  also respect the system's reduce-motion setting and a pause option in the
  app.

### 3. Tagging

- Keep the existing `Need` and `DayPart` taxonomy as the controlled vocabulary.
  Add a few facets: intensity, technique (breathwork, body scan, CBT, …),
  voice or no voice, and good-for-beginners.
- Ingest script: read the audio (duration, loudness, silence) and the
  script or transcript, then propose tags. LLM assistance is allowed, but I
  approve the tags before anything is published.
- Validation: unknown tags are rejected, and every item needs at least one
  Need.

### 4. Recommendations (`GET /v1/recommendations?surface=home|explore|after_session`)

- Signals: practice sessions, saves, completions and skips, session feelings
  (before/after mood), goals, time of day, local timezone, premium status,
  and what is already downloaded when offline.
- Start simple and explainable: tag-affinity scoring, time-of-day fit,
  freshness, diversity (no five sleep sounds in a row) and "continue course"
  first. Return a short reason with each item ("Because evenings are for
  winding down"). Collaborative filtering later, once there's enough data.
- Cold start: use onboarding answers and goals.
- Keep it cheap: precompute per-user lists nightly or after a session ends,
  and serve them from KV or cache instead of scoring on every request.
- The app keeps its current on-device ranking as the offline fallback.
  Server and device must use the same tag vocabulary.
- Safety: crisis and panic tools are never gated or ranked down. Never
  recommend content that conflicts with a negative mood just logged (for
  example a "feeling good" gratitude piece right after a panic entry). Write
  tests for these rules.

### 5. Media delivery and streaming

- Local transcode script (ffmpeg): source WAV/AIFF goes to AAC-LC and/or Opus
  at 64 and 128 kbps, loudness-normalised (about -16 LUFS for voice, quieter
  for sleep sounds), with seamless-loop variants for ambient loops. Long
  pieces (over 10 min) also get HLS. Short ones use progressive download
  with HTTP Range support.
- Content-addressed object keys (hash in the path) with
  `Cache-Control: public, max-age=31536000, immutable`. Artwork goes out in
  WebP/AVIF at a few sizes.
- App: switch `sound_player.dart` to `AudioSource.uri`/HLS with
  just_audio's `LockCachingAudioSource` (or equivalent), pick the bitrate from
  the network type, and keep background playback and lock-screen controls
  working.

### 6. Offline

- A starter pack bundled in the app: breathing, panic reset, a few sleep
  sounds, one or two backgrounds, and the crisis/support content. It must
  work on first launch with no network.
- Downloads: per item and "download this course", Wi-Fi-only by default, a
  storage-used screen, resume after interruption (use `background_downloader`
  or similar), and checksum verification.
- Premium downloads need an entitlement token with an expiry. The app
  re-checks when it's online, and when a subscription lapses the downloads
  become locked. They are not deleted immediately.
- Offline events (plays, completions) are queued on the device and synced
  later, so recommendations stay accurate.

### 7. Security and privacy

- Premium media goes only in the private bucket and is never readable through
  `database.techgetafrica.com`. Nothing premium may be reachable by URL alone.
- Mood, feelings and practice data are health data (GDPR special category).
  Keep them in the EU, send only what recommendations need, delete them
  when the account is deleted (hook into the existing `delete-account`
  function), and keep raw journal text out of the new backend.
- Rate limiting on Worker endpoints, and request size limits.

### 8. Content publishing (just me for now)

- No admin web UI yet. Use a CLI (`npm run publish` or similar) that reads
  content from a folder of Markdown/YAML plus media files in the repo. The
  CLI validates the content, transcodes the audio, uploads it to R2, writes
  the rows to D1, and bumps the catalogue version. The folder in git is the
  source of truth, so I get history and rollback for free.
- Design it so a small web admin (behind Cloudflare Access) can be added
  later if writers or therapists join.

### 9. Operations

- Wrangler config for staging and production, migrations for D1, and CI
  (GitHub Actions) that runs tests and deploys.
- Sentry for the Worker (the app already uses Sentry), plus structured
  logs and an `/healthz` endpoint.
- Rough monthly cost estimate at 1k, 10k and 100k monthly active users.
  Show where we leave the free tier.

## How to work

1. First, read the code listed above and write a short design doc to
   `docs/backend-design.md`. It should cover the data model, endpoints,
   free-tier limits and when we outgrow them, the background format choice,
   the offline and entitlement flow, and open questions. Stop and wait for
   my review.
2. Then build in thin vertical slices, each one usable on its own:
   content folder and migration of existing content → publish CLI and
   catalogue snapshot → transcode and streaming → app integration behind a
   feature flag → offline downloads → premium gating → tagging →
   recommendations → animated backgrounds.
3. Put the Worker in `edge/` and the publishing tools in `tools/content/`.
   The app must keep working with bundled content whenever the backend is
   unreachable.
4. Don't run anything that changes production data or deploys without asking
   me first.
