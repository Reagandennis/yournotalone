# yournotalone-api (Cloudflare Worker)

The Worker from `docs/backend-design.md` §5 (build steps 4, 7 and 8). It runs TypeScript with
Hono, verifies Supabase JWTs with `jose` and presigns R2 URLs with `aws4fetch`.

| Route | Auth | What it does |
|---|---|---|
| `GET /healthz` | none | `{ "ok": true, "catalogVersion": N \| null }` |
| `POST /v1/media/sign` | Supabase JWT | Public CDN URLs for free media, presigned R2 URLs for premium media |
| `POST /v1/recommendations` | Supabase JWT | Ranked item ids with a short reason each (scoring v1) |
| cron `0 3 * * *` | none | Writes `stats/popularity.json` from the `content_popularity` RPC |

## Layout

```
src/index.ts     entry: fetch + scheduled, Sentry wrapper only when SENTRY_DSN is set
src/app.ts       Hono router, CORS, JSON 404/500
src/auth.ts      Bearer JWT -> JWKS verify (iss, aud, exp, sub), per-user rate limit
src/premium.ts   comp flag -> RevenueCat v2, 5-min boolean cache, fails closed
src/catalog.ts   latest.json -> snapshot, in memory, refreshed at most every 60 s
src/sign.ts      POST /v1/media/sign
src/recommend/score.ts       scoring v1: pure, deterministic, no I/O (fixtures in test/fixtures/)
src/recommend/route.ts       POST /v1/recommendations: body checks, parallel reads, scoring
src/recommend/signals.ts     the user's last 90 days from Supabase, with their own JWT (RLS)
src/recommend/popularity.ts  reads stats/popularity.json; the cron that writes it
test/            vitest inside workerd (@cloudflare/vitest-plugin), all network mocked
```

## Develop

```sh
npm install
npm test          # vitest in workerd
npx tsc --noEmit
npm run dev       # wrangler dev; needs .dev.vars with the secrets below
```

## Config

Vars live in `wrangler.toml`. Each `[env.*]` block repeats them because Wrangler doesn't
inherit vars into environments.

| Name | Kind | Value |
|---|---|---|
| `SUPABASE_URL` | var | `https://zpcfavemnvfhqaxqhmri.supabase.co` |
| `SUPABASE_ANON_KEY` | var | The publishable key from `lib/supabase_config.dart`. Public; sent as `apikey` with the user's JWT |
| `PUBLIC_BASE_URL` | var | prod `https://database.techgetafrica.com`, staging `https://database.techgetafrica.com/staging` |
| `R2_ACCOUNT_ID` | var | `f7e65097ea4facdba994ee51d751705a` |
| `BUCKET` | var | `yournotalone` (the one bucket) |
| `KEY_PREFIX` | var | prod `''`, staging `staging/`. Premium media is at `{KEY_PREFIX}private/media/…` |
| `PRO_ENTITLEMENT_ID` | var | RevenueCat's **internal** entitlement id: `entl9d4c5b93da` |
| `PRO_ENTITLEMENT_LOOKUP_KEY` | var | `Techgetafrica Pro`, the fallback used only when `PRO_ENTITLEMENT_ID` is empty |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | secret | R2 API token (S3 credentials) |
| `REVENUECAT_SECRET_KEY` | secret | RevenueCat **v2** secret key |
| `REVENUECAT_PROJECT_ID` | secret | `proj…` |
| `SUPABASE_SERVICE_ROLE_KEY` | secret | Only the cron uses it, to call `content_popularity`. A `sb_secret_…` key or the legacy `service_role` JWT. Without it the cron logs `popularity_skipped` and does nothing |
| `CONTENT_BUCKET` | R2 binding | The `yournotalone` bucket, read-write, for the cron's one write a day. Declared in `wrangler.toml` |
| `SENTRY_DSN` | secret, optional | Sentry stays off when this is unset |

### RevenueCat entitlement id

API v2 `GET /projects/{p}/customers/{id}` lists `active_entitlements.items[]` as
`{ entitlement_id, expires_at }`. `entitlement_id` is RevenueCat's internal id (for example
`entlab12cd34`), **not** the identifier the app uses (`Techgetafrica Pro`, which is the
entitlement's `lookup_key`).

- **Recommended:** In the RevenueCat dashboard, open Product catalog → Entitlements →
  Techgetafrica Pro and copy its id (`entl…`). Put it in `PRO_ENTITLEMENT_ID` for staging and
  production in `wrangler.toml`. You can also get it from
  `GET https://api.revenuecat.com/v2/projects/<proj>/entitlements`.
- **Fallback:** If it's empty, the Worker calls `GET /projects/{p}/entitlements` once per
  isolate and matches on `lookup_key`. That endpoint is limited to 60 requests a minute, and the
  key also needs `project_configuration:entitlements:read`.

Permissions the v2 secret key needs:

- `customer_information:customers:read`;
- `project_configuration:entitlements:read`, only for the fallback.

If you reuse the key the Supabase functions already use, check that it has these permissions.

## Setup (run later, by hand)

1. **Block `private/` on the custom domain.** Everything is in the one bucket,
   `yournotalone`, and the custom domain serves all of it. Premium audio lives under
   `private/` (and `staging/private/`), so add a WAF custom rule (zone `techgetafrica.com` →
   Security → WAF → Custom rules → Create), action **Block**:
   ```
   (http.host eq "database.techgetafrica.com" and lower(url_decode(http.request.uri.path)) contains "/private/")
   ```
   Also make sure the bucket's **r2.dev public URL is off** (R2 → yournotalone → Settings), or
   premium files are reachable there. Signed links go to the S3 endpoint, which the rule
   doesn't touch.
2. **R2 API token for the Worker** (R2 → Manage API tokens → Create):
   - permission **Object Read only**;
   - scoped to the **`yournotalone`** bucket only.

   Presigning a GET only needs read access. Give the publish CLI its own read-and-write token.
   Copy the Access Key ID and Secret Access Key. (These are not the bucket's S3 URL.)
3. **Log in:** `npx wrangler login`.
4. **Secrets**, per environment:
   ```sh
   for env in staging production; do
     npx wrangler secret put R2_ACCESS_KEY_ID      --env $env
     npx wrangler secret put R2_SECRET_ACCESS_KEY  --env $env
     npx wrangler secret put REVENUECAT_SECRET_KEY --env $env
     npx wrangler secret put REVENUECAT_PROJECT_ID --env $env
     npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY --env $env
     npx wrangler secret put SENTRY_DSN            --env $env   # optional
   done
   ```
5. **`PRO_ENTITLEMENT_ID`** is already set to `entl9d4c5b93da`.
6. **Popularity:** run `supabase/migrations/0026_content_popularity.sql` in the SQL Editor
   (it also widens `practice_sessions.kind`). Set `SUPABASE_SERVICE_ROLE_KEY` (Supabase →
   Project Settings → API Keys → a secret key). The `CONTENT_BUCKET` binding needs no token: the
   binding itself grants the Worker access, so the read-only S3 token above stays read-only.
   The first file appears after the next 03:00 UTC run. Until then recommendations score
   without a popularity prior.
7. **Deploy staging:** `npx wrangler deploy --env staging`. That gives you
   `https://yournotalone-api-staging.<subdomain>.workers.dev`. Production is
   `npx wrangler deploy --env production` (`yournotalone-api.<subdomain>.workers.dev`).

## curl

```sh
API=https://yournotalone-api-staging.<subdomain>.workers.dev
curl -s $API/healthz
# {"ok":true,"catalogVersion":7}

TOKEN=<a Supabase access token, e.g. from supabase.auth.currentSession.accessToken>
curl -s -X POST $API/v1/media/sign \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"items":["meditation:Body scan","sound:Rainfall"],"purpose":"stream"}'
# {"urls":{"sound:Rainfall":{"audio":{"url":"https://…/media/<sha>.m4a","expires":null,"sha256":"…","bytes":812345}},
#          "meditation:Body scan":{"narration":{"url":"https://<acct>.r2.cloudflarestorage.com/…?X-Amz-…&X-Amz-Signature=…",
#                                  "expires":"2026-11-02T19:00:00.000Z","sha256":"…","bytes":9000000}}},
#  "missing":[]}

curl -s -X POST $API/v1/recommendations \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"surface":"home","localTime":"2026-11-02T21:14","lastMood":0,"lastMoodAt":"2026-11-02T18:05:00Z","opensByKind":{"sound":12}}'
# {"items":[{"id":"tool:Grounding: 5-4-3-2-1","reason":"For right now"},
#           {"id":"breathing:Panic reset","reason":"For right now"}, …],
#  "rules":"v1","catalogVersion":7}
```

### `POST /v1/recommendations`

Every field is optional:

| Field | Meaning |
|---|---|
| `localTime` | The phone's wall clock, `YYYY-MM-DDTHH:mm`: part of the day, "new", the daily shuffle |
| `tz` | IANA zone, used for the wall clock when `localTime` is missing (else UTC) |
| `lastMood`, `lastMoodAt` | Last check-in, 0 awful … 4 great. 0 or 1 within 2 hours (or with no time) turns on the safety rules |
| `opensByKind` | Opens per kind on this device; a small tie-breaker |
| `course` | `{"id": "sleep7", "day": 2}`: the course in progress and its next day (0-based), which goes first |
| `limit` | 1–20, default 6 |
| `surface`, `catalogVersion`, `locale`, `downloaded`, `offline` | Checked and accepted; not used by v1 |

The Worker adds the last 90 days of `practice_sessions` and `session_feelings`, the
`saved_items`, goals from the JWT (`user_metadata.goals`), premium (as for signing) and the
popularity snapshot. The Supabase reads use the caller's JWT, so RLS applies; each has a 1.5 s
timeout, and one that fails (or a table that isn't migrated yet) is treated as empty. Supabase
being down never fails the request. Reasons are English for now.

Scoring rules, weights and reason strings are in `src/recommend/score.ts`. The fixtures in
`test/fixtures/recommendations/` pin exact outputs for a future Dart port.

Errors are always JSON, `{"error": "<code>"}`:

| Status | Codes |
|---|---|
| 400 | `bad_request` |
| 401 | `missing_token`, `token_expired`, `invalid_token` |
| 403 | `premium_required` |
| 429 | `rate_limited` |
| 503 | `catalog_unavailable` |

## Free-tier notes

- **Requests:**
  - 100k Worker requests a day and 10 ms CPU per request.
  - `/healthz` and the daily cron count as requests too.
  - Free media never needs the Worker: the app can build the CDN URL itself. Only call
    `/v1/media/sign` for premium media, and batch items (up to 50 a call).
- **CPU:**
  - ES256 verification and one SigV4 presign per premium ref fit well inside 10 ms.
  - JWKS and the catalogue live in isolate memory. JWKS is cached for 10 minutes; the
    catalogue is checked every 60 seconds, and a new snapshot is only downloaded when
    `latest.json` changes.
- **Bundle:** about 140 KiB gzipped (mostly Sentry), against the 3 MiB free limit.
- **Cache API:**
  - The premium boolean is kept for 5 minutes in `caches.default` and in a small in-isolate map.
  - Cloudflare's docs only promise that the Cache API works on custom domains. On
    `*.workers.dev` it may not store anything, which would make the in-isolate map the only
    cache. RevenueCat's customer endpoint allows 480 requests a minute.
  - Moving to a custom domain later fixes this.
- **Rate limiting:**
  - `[[ratelimits]]` allows 60 requests a minute per user, per Cloudflare location.
  - Cloudflare's docs don't say this binding is paid-only. If a deploy on the free plan rejects
    it, delete the `[[…ratelimits]]` blocks; the code skips the check when the binding is
    missing.
  - `namespace_id` values (1001–1003) only need to be unique in your account.
- **R2:**
  - Presigned GETs go straight to R2 (Class B reads, 10M a month free; egress is free).
  - The Worker never proxies media bytes.
- **Recommendations:**
  - Scoring 250 items against 300 sessions and 300 feelings takes about 0.2 ms of CPU (Node,
    warm). Waiting on Supabase doesn't count towards the 10 ms CPU limit.
  - Each call makes up to 5 subrequests: 3 Supabase reads, RevenueCat (cached 5 min) and
    `stats/popularity.json` (cached in memory for an hour). The free plan allows 50.
  - The cron is one RPC call and one R2 write (Class A) a day.
- **Not used:** KV, D1, Durable Objects, Queues. Nothing user-specific is stored on Cloudflare
  except the 5-minute premium boolean, keyed by sha256(user id). Recommendation answers are sent
  with `Cache-Control: private, no-store`.
