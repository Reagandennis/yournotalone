# yournotalone-api (Cloudflare Worker)

The Worker from `docs/backend-design.md` §5 (build step 4). It runs TypeScript with Hono,
verifies Supabase JWTs with `jose` and presigns R2 URLs with `aws4fetch`.

| Route | Auth | What it does |
|---|---|---|
| `GET /healthz` | none | `{ "ok": true, "catalogVersion": N \| null }` |
| `POST /v1/media/sign` | Supabase JWT | Public CDN URLs for free media, presigned R2 URLs for premium media |
| cron `0 3 * * *` | none | Stub that logs `popularity: not yet` (build step 8) |

`/v1/recommendations` comes later. Add it as `registerRecommendations(app)` in `src/app.ts`,
next to `registerSign`. `/v1/*` is already behind the auth middleware.

## Layout

```
src/index.ts     entry: fetch + scheduled, Sentry wrapper only when SENTRY_DSN is set
src/app.ts       Hono router, CORS, JSON 404/500
src/auth.ts      Bearer JWT -> JWKS verify (iss, aud, exp, sub), per-user rate limit
src/premium.ts   comp flag -> RevenueCat v2, 5-min boolean cache, fails closed
src/catalog.ts   latest.json -> snapshot, in memory, refreshed at most every 60 s
src/sign.ts      POST /v1/media/sign
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
| `PUBLIC_BASE_URL` | var | prod `https://database.techgetafrica.com`, staging `https://database.techgetafrica.com/staging` |
| `R2_ACCOUNT_ID` | var | `f7e65097ea4facdba994ee51d751705a` |
| `BUCKET` | var | `yournotalone` (the one bucket) |
| `KEY_PREFIX` | var | prod `''`, staging `staging/`. Premium media is at `{KEY_PREFIX}private/media/…` |
| `PRO_ENTITLEMENT_ID` | var | RevenueCat's **internal** entitlement id: `entl9d4c5b93da` |
| `PRO_ENTITLEMENT_LOOKUP_KEY` | var | `Techgetafrica Pro`, the fallback used only when `PRO_ENTITLEMENT_ID` is empty |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | secret | R2 API token (S3 credentials) |
| `REVENUECAT_SECRET_KEY` | secret | RevenueCat **v2** secret key |
| `REVENUECAT_PROJECT_ID` | secret | `proj…` |
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
     npx wrangler secret put SENTRY_DSN            --env $env   # optional
   done
   ```
5. **`PRO_ENTITLEMENT_ID`** is already set to `entl9d4c5b93da`.
6. **Deploy staging:** `npx wrangler deploy --env staging`. That gives you
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
```

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
- **Not used:** KV, D1, Durable Objects, Queues. Nothing user-specific is stored on Cloudflare
  except the 5-minute premium boolean, keyed by sha256(user id).
