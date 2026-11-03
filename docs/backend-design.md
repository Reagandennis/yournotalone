# Content backend: design

Status: draft for review (2026-11-02). Nothing is built yet.
Brief: `docs/backend-prompt.md`.

## 1. What the code tells us

Read before designing, because it changes the plan:

- **Most content is already data, not code.** Breathing patterns are four
  numbers. Meditations are timed text prompts plus an optional narration
  file. Sounds are an audio file plus wave parameters. Lessons are
  paragraphs, journal prompts are a title and seed text, and courses are
  lists of item ids. All of these can come from a server.
- **Some items are screens.** Toolkit tools (`ToolkitTool.open` is a
  `WidgetBuilder`) and the recovery tools (HALT, Play the tape forward …)
  are Dart code. They stay in the app. The server can only add tags to them.
- **Ids are `kind:Title`** (`ContentItem.id`). Saves (`SavedStore`), course
  days (`CourseDay.itemId`) and the tag table already use them, and
  `practice_sessions.slug` / `session_feelings.slug` store the title.
  Changing ids would break people's history, so **existing items keep
  their current id forever**, and only new items get short slug ids. No
  user data has to be migrated.
- **Audio is small and already bundled.** `assets/sounds` holds 14 MB of
  AAC. The 196 MB in `Sounds/` is raw masters, and it is tracked in git.
  No meditation has narration yet (`assets/narration` holds only a README).
  So streaming matters for future content more than for today's.
- **Premium is checked on the device** (`isPremiumUser()`: RevenueCat
  `isPro`, or `app_metadata.premium_comp`), and RevenueCat's app user id is
  the Supabase user id. The server can therefore verify premium the same
  way.
- **The app has no localisation.** All copy is in English, in Dart, and
  there is no l10n setup. We're adding French, German, Spanish and Chinese
  (see §7a).
- **Recommendation signals:** `practice_sessions` and `session_feelings`
  are in Supabase. Opens per kind, saves and recent searches are only on the
  device. Goals are in `user_metadata.goals`.

## 2. Architecture

```
                 ┌────────────── Cloudflare ───────────────┐
 Flutter app ──► │ database.techgetafrica.com  (R2 public)  │  catalogue, free audio,
   (CDN, cached) │   bucket: yournotalone      CDN-cached   │  artwork, backgrounds
                 │                                          │
             ──► │ Worker  api  (TypeScript, Hono)          │  sign premium URLs,
   (JWT)         │   ├─ verifies Supabase JWT               │  recommendations,
                 │   ├─ checks premium (JWT / RevenueCat)   │  healthz
                 │   ├─ presigns ► R2 private bucket        │
                 │   └─ cron: daily popularity snapshot     │
                 └──────────────┬───────────────────────────┘
                                │ user's JWT (RLS) / service key for aggregates
                                ▼
                     Supabase (unchanged system of record)

 My Mac:  content/ (git) ──npm run publish──► ffmpeg ► R2 + catalogue snapshot
```

### Deviations from the brief, and why

1. **No D1 in v1.** The source of truth for content is a folder in git (just
   one editor, so git gives history and rollback). The published catalogue is
   one JSON file of a few hundred KB that the Worker and the app both load
   whole. Recommendations read user signals from Supabase, where they
   already live. That leaves nothing that needs querying with SQL, so D1
   would only add a second copy of data. It can come back when there's an
   admin web UI or server-side search.
2. **No KV, and no nightly precomputed recommendations.** KV's free plan
   allows 1,000 writes a day, so a nightly per-user precompute would stop
   working at 1,000 users. Scoring about 150 items for one person takes well
   under a millisecond, so the Worker scores on request, and the app caches
   the result.
3. **No HLS in v1.** At 64 kbps a 20-minute session is about 10 MB.
   Progressive AAC with HTTP Range requests starts as fast as HLS for files
   this size. HLS splits a session into hundreds of segment requests, and
   each request to the private bucket counts as an R2 operation. just_audio's
   caching source also doesn't cache HLS. HLS can be added later, for video.
4. **No separate offline entitlement token.** RevenueCat's SDK caches the
   customer's entitlements on the device and `isPremiumUser()` already works
   offline. Downloaded premium files go through the same `openContent` gate
   as everything else. See §6.
5. **Backgrounds are code-drawn first, not Rive.** See §7.

## 3. Free-tier budget

These are Cloudflare's published limits, checked 2026-11-02:

| Resource | Free | We use it for |
|---|---|---|
| Workers requests | 100k / day, 10 ms CPU each | recommendations, premium URL signing |
| R2 storage | 10 GB-month | masters + renditions + art |
| R2 Class A (writes) | 1M / month | publishing only |
| R2 Class B (reads) | 10M / month | CDN cache misses, presigned premium plays |
| R2 egress | free | all media |
| Cron Triggers | billed as Worker requests | 1 run a day |

Requests per daily active user (DAU), estimated:

- 0 Worker requests for opening the app. The catalogue check is a CDN-cached
  file on the public domain.
- About 2 recommendation calls: Home on open, and after a session. The
  device keeps the result for 3 hours.
- About 2 signing calls for premium plays or downloads. One call can sign
  several items.

That comes to **about 4 Worker requests per DAU**, so the free plan covers
about **25k DAU (roughly 100k MAU)**. Workers requests are the first limit
we'd hit. R2 reads stay low because free audio comes from the CDN cache, and
each premium play makes only 1–3 Range reads. R2 storage holds about 20,000
minutes of 64 kbps audio before it reaches 10 GB.

| MAU | Cloudflare cost / month |
|---|---|
| 1k | $0 |
| 10k | $0 |
| 100k | $0–5. Near the daily cap, so move to Workers Paid ($5, which includes 10M requests a month). |
| 500k | about $5–10 |

Supabase usage (one indexed read per recommendation call) is billed
separately, under the plan you already have.

The CDN only caches `.m4a` and `.json` if we tell it to. The domain needs
one **Cache Rule**: "eligible for cache, respect origin `Cache-Control`" for
`database.techgetafrica.com`. Free plans include Cache Rules.

## 4. Content model

### Folder layout (in git)

```
content/
  vocab.yaml                 # needs, dayParts, facets — the controlled vocabulary
  items/
    breathing/box-breathing.yaml
    meditation/body-scan.yaml
    sound/rainfall.yaml
    lesson/cbt-thinking-traps.yaml
    prompt/hard-days-1.yaml
    native/halt-check.yaml   # app-built screens: tags only
  courses/sleep7.yaml
  backgrounds/dusk-waves.yaml
masters/                     # NOT in git — lives in the private bucket under masters/
```

### Item (YAML)

```yaml
id: breathing:Box breathing    # legacy items keep their kind:Title id; new ones e.g. med-morning-reset
kind: breathing                # where it's listed: breathing | meditation | sound | prompt | tool | lesson | recovery
status: published              # draft | published | retired
order: 10                      # list position
premium: false
addedOn: 2026-09-01
minutes: 3
text:
  en:
    title: Box breathing
    blurb: Even sides, steady mind — used by athletes and navy divers alike.
tags:
  needs: [anxious, stressed, focus]
  dayParts: []
  technique: breathwork        # facet
  intensity: gentle            # gentle | moderate | deep
  beginner: true
  voice: false
  calmingSafe: true            # allowed straight after a distressed check-in (§5)
accent: blue
background: dusk-waves         # optional default background
body:                          # body.type says what it is
  type: breathing              # breathing | meditation | sound | prompt | lesson | native
  inhale: 4
  holdIn: 4
  exhale: 4
  holdOut: 4
```

The `body` differs by kind:

- **meditation:** `prompts: [[0.0, "…"], …]` and optional
  `narration: masters/body_scan.wav`.
- **sound:** `audio: masters/rainfall.wav`, `loop: true`, `category`, and
  wave parameters.
- **lesson:** `paragraphs`.
- **prompt:** `group`, `seed`.
- **native:** only `screen: halt` (a key the app maps to its Dart screen)
  and tags.

`text` is keyed by locale (`en`, `fr`, `de`, `es`, `zh-Hans`), with `en`
required. Narration can also be per locale (`narration: {en: …, fr: …}`).
If an item has no recording in the user's language, it plays the on-screen
text only and never falls back to English audio. See §7a. A `video` kind can
be added later with the same media rendition model.

### Published catalogue snapshot

`npm run publish` writes:

- `catalog/v{N}-{hash}.json`: the whole published catalogue. Items carry
  resolved media refs, for example
  `{"url": "media/3f9a…c1.m4a", "bytes": 812345, "sha256": "…", "access": "public"}`
  or `"access": "premium"`. Premium items have no URL, only the hash and size.
  Cached with `immutable, max-age=31536000`.
- `catalog/latest.json`: `{"version": N, "path": "catalog/v{N}-{hash}.json", "minApp": "1.2.0"}`,
  cached with `max-age=60`. If the app is older than `minApp`, it keeps its
  current catalogue instead of loading one it can't read.
- `assets/catalog/bundled.json` in the app: the same format, generated by
  the same command. The app ships with a full working catalogue.

### Object keys

One bucket, `yournotalone` (changed 2026-11-02: the user wants the bucket
they already made, not four):

- `catalog/…`, `media/{sha256}.m4a` (free audio), `art/{sha256}.{webp,avif}`,
  `bg/{sha256}.json` (Lottie, later). Everything except `latest.json` is
  content-addressed and immutable.
- `private/media/{sha256}.m4a` (premium audio) and `private/masters/…`
  (source WAV/AIFF, kept as a backup). A WAF custom rule blocks any path
  containing `/private/` on `database.techgetafrica.com`, and the r2.dev URL
  is off, so these are only reachable through presigned S3 URLs.
- `staging/…`: the same layout for staging, served at
  `database.techgetafrica.com/staging`.

## 5. Worker API

The Worker runs on the free `*.workers.dev` address (for example
`yournotalone-api.<account>.workers.dev`). Moving to a custom domain later
only changes one URL in the app config.

All endpoints need `Authorization: Bearer <Supabase access token>`, except
`/healthz`. The Worker verifies the token's signature against the project's
JWKS (`<project>.supabase.co/auth/v1/.well-known/jwks.json`, using the
asymmetric signing keys the project already has), so no JWT secret is stored
on Cloudflare. It also checks `exp`, `iss`, and `aud = authenticated`. The
JWKS is cached in memory for 10 minutes. Every endpoint is rate-limited per user with the
Workers rate-limiting binding.

### `POST /v1/media/sign`

```json
// request
{ "items": ["meditation:Body scan"], "purpose": "stream" }   // or "download"
// response
{ "urls": { "meditation:Body scan": { "url": "https://…r2.cloudflarestorage.com/…?X-Amz-…", "expires": "…" } } }
```

- Free items get the public CDN URL, no signing needed.
- Premium items require premium. That is `app_metadata.premium_comp` in the
  JWT, or else a RevenueCat v2 call for an active `Techgetafrica Pro`
  entitlement. The RevenueCat answer is cached in the Cache API for
  5 minutes, keyed by a hash of the user id, and stores a boolean only.
  Without premium the endpoint returns 403.
- Presigned with `aws4fetch` against the S3 endpoint. Expiry is 6 hours for
  streaming and 1 hour for downloads (long enough to start; Range requests
  carry on with the same URL).

### `POST /v1/recommendations`

```json
// request (device-only signals ride along; nothing is stored)
{ "surface": "home", "tz": "Africa/Nairobi", "localTime": "2026-11-02T21:14",
  "catalogVersion": 42, "locale": "fr", "lastMood": 0, "lastMoodAt": "…",
  "opensByKind": {"sound": 12, "meditation": 3},
  "downloaded": ["meditation:Body scan"], "offline": false }
// response
{ "items": [ { "id": "breathing:Panic reset", "reason": "For right now" }, … ],
  "rules": "v1" }
```

The server adds the last 90 days of `practice_sessions` and
`session_feelings`, plus the user's `saved_items`, fetched from Supabase with the user's own JWT (RLS
applies, so the Worker never sees anyone else's rows), plus goals from the
JWT and the daily popularity snapshot.

**Scoring, v1** (deterministic, so the same code can run on the device):

1. **Safety first.** If `lastMood ≤ 1` (awful or low) in the last 2 hours,
   the list leads with the panic or grounding items and the support card.
   Only items tagged `calmingSafe` are allowed, and nothing tagged
   `Need.good` or "high intensity". Crisis and support items are always free
   and never ranked down.
2. **Continue the course** in progress, if any.
3. Score = need affinity (goals, then needs of items finished with
   "felt better", minus needs of items finished "felt worse")
   + time-of-day fit
   + freshness (`addedOn` < 21 days)
   + small popularity prior
   − recently done (finished in the last 24h).
4. **Diversity:** at most 2 items of one kind in the top 6, and at most 1
   from one course.
5. **Reason:** the strongest scoring term becomes a short line, for example
   "Because you felt better after Body scan".
6. For a free user, premium items are capped at 2 of the top 6, so Home
   never looks like a wall of locks. Locked items still show, because they
   lead to the upgrade sheet.

Unit tests cover every safety rule (§9). The function lives in its own
module. If we decide later to run it on the device too, it's small enough
to port to Dart, with shared JSON test fixtures keeping both versions in
step.

### `GET /healthz`

Returns the version and whether the catalogue loads.

### Cron (daily, 03:00 UTC)

Calls a `security definer` Supabase RPC, `content_popularity(days => 30)`,
using the service key. It returns only aggregate counts per slug, dropping
any count under 10, and writes `stats/popularity.json` to the public bucket.
That's one R2 write a day and no personal data.

**What Cloudflare stores about users: nothing.** Per-user data passes
through the Worker in memory and isn't cached. The only exception is a
5-minute premium boolean. Mood and session data stay in Supabase (EU), and
account deletion needs no new code because nothing user-specific lives on
Cloudflare.

## 6. App side

### Catalogue

- **`CatalogRepository`** loads, in order:
  1. `assets/catalog/bundled.json`;
  2. the last downloaded snapshot from the app support directory;
  3. in the background, `latest.json`. If the version is newer, it
     downloads the snapshot, checks its hash and swaps it in.
- **`contentIndex` becomes a `ValueNotifier<List<ContentItem>>`** built from
  the catalogue. `native` items are joined to their Dart screens through a
  `screen` key map in the app. If a key isn't known, the item is hidden, so
  an older app never shows a tile it can't open.
- The existing test that checks every tag key has a real item becomes a test
  on the bundled snapshot.
- Everything sits behind a `remoteCatalog` flag. With the flag off, the app
  behaves exactly as it does today.

### Playback

- `SoundPlayer` identifies sounds by asset path today. It moves to a
  `MediaRef`: bundled asset, local file, or remote URL plus sha256.
- **Loops** (sounds) download the whole file before playing (they are
  40 KB–2.5 MB). A gapless loop needs the whole file anyway, and the cached
  copy is reused.
- **Narration** streams with `LockCachingAudioSource`. It is given an
  explicit `cacheFile` named after the sha256, so a fresh signed URL each
  time still hits the same cache.
- Background playback, the `MediaItem` tag and lock-screen controls work as
  they do today.

### Downloads (offline)

- `background_downloader` (resumable, survives the app being closed),
  Wi-Fi-only by default, files saved to the app support directory as
  `media/{sha256}.m4a`, each file's hash checked after download.
- "Download course" queues every item in the course.
- A storage screen in Settings shows the size per item and has a
  remove-all button.
- **Lapsed premium:** files stay on the device and `openContent` shows the
  upgrade sheet, as it does for any locked item. That works offline because
  RevenueCat caches entitlements. Downloads of premium items are deleted
  only if the subscription has been inactive for 30 days and the user
  confirms. (The protection is the paywall, not encryption. Someone could
  pull files off a rooted phone. Accepted.)
- **Starter pack bundled in the app:** all breathing patterns (no audio
  needed), Panic reset, Urge surf, support and crisis content, 3 free
  sounds, 2 backgrounds. That's about 3 MB, down from 14 MB today, because
  the other sounds become downloads.
- **Offline events:** `practice_sessions` and `session_feelings` inserts are
  already per-row. Failed inserts go into a small queue on the device and
  are retried when the app is next online.

New packages: `background_downloader`, `path_provider`,
`connectivity_plus`, `crypto`.

## 6a. Saves across devices

- **New Supabase table `saved_items`:** `user_id`, `item_id` (the content
  id), `saved_at`, with primary key `(user_id, item_id)`. Rows are deleted
  when the account is deleted (`on delete cascade`). RLS limits each user to
  their own rows.
- **`SavedStore` stays the fast local copy.** Toggling a heart updates the
  device at once and writes to Supabase in the background. Writes that fail
  offline wait in the same retry queue as session events.
- **Merge rule** on sign-in, and when the app comes to the foreground at
  most once an hour: the union of device and server saves. Removals are
  synced as deletes, so an item unsaved on one phone doesn't come back from
  the other.
- **First sync after the update:** the device uploads whatever it already
  has saved, so nobody loses existing saves.
- The Worker doesn't touch this. The app talks to Supabase directly, as it
  does for journal entries. Saves stop being sent in the recommendations
  request because the Worker can read them from Supabase.

## 7a. Localisation (en, fr, de, es, zh-Hans)

There are two separate jobs.

**App UI strings.** Every screen's copy is in Dart today.

- Move it to Flutter's `gen-l10n`: one ARB file per locale and
  `AppLocalizations`.
- Add `flutter_localizations` and `intl`.
- Language follows the phone's language, with a manual override in
  Settings.
- This touches every screen, so it's its own track (§10). It can run in
  parallel with the backend work.

**Content.** This is the `text` (and optional narration) per locale in the
content YAML.

- `npm run translate -- ID --to fr,de,es,zh-Hans` (in `tools/content`)
  drafts translations with Claude into `text.<locale>` with
  `reviewed: false`.
- Nothing is shown in release builds until a locale is marked
  `reviewed: true`. Mental-health wording (CBT terms, crisis copy) needs a
  fluent human check. Machine translation alone isn't good enough here.
  (Changed 2026-11-03: drafts are published with `reviewed: false` so
  testers can see them in builds with drafts on; release builds ignore
  them.)
- The app shows an item in your language if that locale is reviewed, and
  otherwise in English with a small "EN" label. Search and tags work across
  languages because tags are language-neutral.

**Crisis and support content depends on the country, not the language.**
French doesn't tell us whether someone is in France, Canada or Senegal.
Helplines are keyed by country, using the device region with a "change
country" option. They need a separate verified list, with a human check
before each one ships.

**Chinese.**

- Poppins has no CJK glyphs, so Chinese text uses the system font
  (PingFang on iOS, Noto Sans CJK on Android). That needs a font fallback in
  the theme, and layouts need checking because CJK text is taller.
- `*.workers.dev` and Supabase are unreliable or blocked in mainland China,
  and the Play Store and Google sign-in aren't available there. So `zh-Hans`
  serves Chinese speakers outside the mainland (Singapore, Malaysia, the
  diaspora). Serving mainland China would mean a separate China-hosted
  stack, which is out of scope.

## 7. Animated backgrounds

| Option | Size | Battery / low-end Android | Making them (just me) | Cost |
|---|---|---|---|---|
| **Code-drawn (CustomPainter + shader)** | 0 bytes (server sends parameters) | Best. GPU, can pause | Dart code. Already how the sound player wave and toolkit art work | Free |
| Lottie (`lottie` package) | 20–300 KB JSON | OK for simple vectors, CPU-heavy for complex ones | LottieFiles has free assets. Making your own needs After Effects or LottieFiles Creator | Free to use |
| Rive | 10–100 KB | Good | Rive editor, but **exporting `.riv` needs a paid plan (about $9/month)** | Paid |
| Looping video | 0.5–3 MB | Hardware-decoded, but a video surface stays on | Easiest to make | Free. Arrives with video later |

**Recommendation:** build 3–4 **code-drawn "scene engines"** (waves, aurora,
drifting particles, slow gradient). Each one takes parameters (palette,
speed, density, seed), so each new background is just a YAML file with no
download and works offline at once. Add **Lottie** as a second kind for
drawn art that code can't do. Revisit Rive or video when video arrives.

All backgrounds:

- respect `MediaQuery.disableAnimations` (reduce motion);
- have an in-app "Calm visuals: off" switch;
- drop to 30 fps;
- pause when the screen is in the background or the battery saver is on.

## 8. Publishing workflow (`tools/content`, Node + TypeScript)

```
npm run content:check            # validate YAML against schema + vocab, ids unique, course refs exist
npm run content:suggest-tags ID  # optional: Claude proposes tags into `suggested:`; I copy what I agree with
npm run content:publish -- --env staging|production [--dry-run]
```

`publish` does the following:

1. Validates the content (zod schemas). Unknown tags, missing `en` text and
   items with no Need all fail.
2. Transcodes new or changed masters with ffmpeg:
   - two-pass `loudnorm` to −16 LUFS for voice and −23 LUFS for sleep
     sounds;
   - AAC-LC mono, 64 kbps for voice and 96 kbps stereo for ambient sounds;
   - loops get a crossfaded seamless join, checked by ear the first time.
3. Hashes each file, and uploads only hashes R2 doesn't already have (with
   the S3 API and a scoped R2 token).
4. Writes the versioned snapshot, then `latest.json` last, so a reader never
   sees a pointer to a missing file.
5. Regenerates `assets/catalog/bundled.json` for the next app build.

Rolling back means `git revert` and publishing again.

Staging uses the `staging/` prefix in the same bucket, plus a staging Worker, so a test build can
point at staging.

`suggest-tags` uses the Claude API (`claude-haiku-5-5`, well under $1 for
the whole catalogue). The model only writes into `suggested:` and never into
`tags:`.

**One-time migration (the first slice):** a Dart test-harness script walks
today's `contentIndex` and catalogues and writes `content/items/**.yaml`,
keeping `kind:Title` ids and merging in `content_tags.dart`. A test then
checks that the bundled snapshot reproduces today's index item for item.

## 9. Testing and operations

- **Worker:** Vitest with `@cloudflare/vitest-pool-workers`. It covers JWT
  rejection cases (expired, wrong audience, forged), premium checks
  (comp flag, RevenueCat on, RevenueCat off or erroring, which fails
  closed), and signing.
- **Recommendation safety tests:**
  - after an awful mood, the first item is the panic or grounding item;
  - no `good` or high-intensity item appears;
  - crisis items are never locked;
  - the diversity caps hold;
  - the free-user premium cap holds.
- **App:** catalogue loading (bundled, then cached, then remote with a bad
  hash rejected), the `minApp` gate, the download hash check, and
  `MediaRef` playback paths.
- **Infrastructure:**
  - `wrangler.toml` with `staging` and `production` environments;
  - GitHub Actions running `content:check`, Worker tests and
    `flutter test`. Deploying the Worker is a manual workflow run.
- **Monitoring:**
  - `@sentry/cloudflare` in the Worker, the same org as the app;
  - structured JSON logs (Workers Logs);
  - `/healthz`.

## 10. Build order (each step usable on its own)

**Backend and content track:**

1. Content folder, migration script, bundled snapshot; the app reads it
   (flag off, output identical).
2. `content:publish` to staging, public bucket, Cache Rule; the app fetches
   `latest.json` with the flag on.
3. Move `Sounds/` masters to the private bucket under `masters/`, then stop
   tracking them in git (§12, decision 4). Transcode pipeline; free sounds
   stream and download from the CDN; bundled audio cut to the starter pack.
4. Worker on workers.dev with `/media/sign`; premium plays and downloads.
5. Downloads UI, storage screen, offline event queue.
6. `saved_items` table and save sync.
7. `/recommendations` with safety tests; Home uses it, with the on-device
   order as the fallback.
8. `content_popularity` RPC and cron.
9. Code-drawn background engines, then Lottie.
10. `content:suggest-tags` and `content:translate`.

**Localisation track (in parallel):**

- L1. `gen-l10n` set up; move every UI string to `app_en.arb`, with no
  visible change.
- L2. CJK font fallback and layout checks; language override in Settings.
- L3. Draft fr, de, es and zh-Hans ARB files plus content translations;
  human review, locale by locale.
- L4. Country-keyed crisis and helpline list, verified.

## 11. What I'll need from you (when we get there, not now)

- Create the private and staging R2 buckets, and an R2 API token scoped to
  them (for presigning and the publish CLI).
- Add the Cache Rule on `database.techgetafrica.com`.
- Run `wrangler login`. The Worker deploys to your workers.dev subdomain.
- Set Worker secrets: R2 keys, `REVENUECAT_SECRET_KEY` (the one the
  Supabase functions already use), and `SENTRY_DSN`.
- Run the Supabase migrations: the popularity RPC, `saved_items`, and
  widening the `practice_sessions.kind` check to allow `lesson`, `prompt`
  and `tool`.
- Find fluent reviewers for French, German, Spanish and Chinese, and
  confirm which countries' helplines to list.

## 12. Decisions (2026-11-02)

1. **Languages:** English plus French, German, Spanish and Chinese
   (Simplified, `zh-Hans`), for both the app UI and the content. See §7a.
2. **Worker hostname:** the free `*.workers.dev` address for now.
3. **Supabase JWT signing:** the project uses asymmetric signing keys
   (JWKS), so no JWT secret is stored on Cloudflare.
4. **`Sounds/` masters:** move them to the private bucket and stop tracking
   them in git from then on. Git history keeps the old copies. It won't be
   rewritten unless you ask separately.
5. **Saves sync across devices** through Supabase (§6a).
6. **The bundled audio shrinks** to a roughly 3 MB starter pack. The other
   sounds become one-tap downloads.

## 13. Still open

- **Simplified Chinese only, or Traditional too?** Traditional (`zh-Hant`)
  would be for Taiwan and Hong Kong. Adding it later is cheap, because it's
  just another locale key.
