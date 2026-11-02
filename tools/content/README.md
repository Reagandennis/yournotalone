# Content tools

Node package that checks `content/`, builds the catalogue snapshot the app
bundles, and publishes the catalogue and its audio to Cloudflare R2. Design:
`docs/backend-design.md` §4 and §8.

It runs TypeScript directly through Node's type stripping (Node 24 or later),
with no build step.

```
npm install
npm run check                                  # validate content/
npm run build                                  # write assets/catalog/bundled.json
npm run publish -- --env staging --dry-run     # see what a publish would do
npm test
```

## Publishing

```
npm run publish -- --env staging|production [--dry-run]
```

Steps:

1. Checks `content/` the same way `npm run check` does, and stops on any
   error.
2. Prepares the audio of every published item: `body.audio` for sounds and
   `body.narration` for meditations.
   - WAV, AIFF and FLAC masters go through ffmpeg: a two-pass `loudnorm`,
     then AAC-LC.
     - Narration (voice): -16 LUFS, true peak -1.5 dB, mono, 64 kbps.
     - Sounds (ambient): -23 LUFS, true peak -1.5 dB, stereo, 96 kbps.
   - `.m4a` files are already AAC, so they're uploaded byte for byte.
   - `.aac` is copied into an MP4 container without re-encoding.
   - MP3 is re-encoded with a warning. Supply a lossless master instead if
     you can.
   - Transcodes are cached in `.cache/`, keyed by the source's sha256 and
     the settings. Delete the folder to force a re-encode.
   - Seamless-loop crossfades aren't done yet (there's a TODO in
     `src/transcode.ts`).
3. Names each file by its content: `media/<sha256>.m4a`. Free items go to
   the public bucket with `"access": "public"`. Premium items go to the
   private bucket with `"access": "premium"`, and the Worker signs URLs for
   those.
4. Builds the snapshot, the same one `npm run build` makes, plus a `media`
   map:
   `{"<item id>": {"audio"?: MediaRef, "narration"?: MediaRef}}`, where
   `MediaRef` is `{key, sha256, bytes, access}`. The version is one more
   than the target's current `latest.json`, or 1 if there isn't one.
5. Uploads, in this order:
   1. media the bucket doesn't have yet (checked with HEAD first);
   2. `catalog/v{N}-{hash}.json`;
   3. last, `catalog/latest.json` =
      `{"version": N, "path": "catalog/v{N}-{hash}.json", "minApp": "1.1.0"}`.

   Media and the versioned snapshot get
   `Cache-Control: public, max-age=31536000, immutable`. `latest.json` gets
   `public, max-age=60`. Because `latest.json` goes last, a reader is never
   pointed at a file that isn't there yet.

If the catalogue hash matches the current `latest.json`, it says so and
uploads nothing. The hash covers the items, courses and media refs, so
re-encoding or replacing an audio file also counts as a change.

`--dry-run` prints the plan: each object, its size and bucket, whether it
would be uploaded, and the new version. It also writes the would-be files to
`.out/<env>/<bucket>/<key>`. A dry run makes no network requests and needs no
credentials, so it can't see the bucket. It shows media as `upload?` and
assumes there is no current `latest.json`, so it always plans v1.

`minApp` is set in `src/config.ts`. Raise it when the app needs new code to
read the catalogue.

Publishing doesn't touch `assets/catalog/bundled.json`. Run `npm run build`
for that before an app build.

### Credentials

| Variable | |
|---|---|
| `R2_ACCESS_KEY_ID` | R2 API token access key id |
| `R2_SECRET_ACCESS_KEY` | R2 API token secret |

These are read only for a real publish. If one is missing, the command stops after the content check,
before it prepares media or makes a request.

Create the token in the Cloudflare dashboard under **R2 → Manage API
tokens**. It needs **Object Read & Write**, applied to the `yournotalone`
bucket only.

Everything goes in that one bucket:

| Key | What |
|---|---|
| `catalog/latest.json`, `catalog/v{N}-{hash}.json` | the catalogue |
| `media/{sha256}.m4a` | free audio, public on the CDN |
| `private/media/{sha256}.m4a` | premium audio, blocked on the custom domain; the Worker signs links |
| `staging/…` | the same layout for staging |

It doesn't need admin or bucket-management permissions. Requests go to the S3
endpoint `https://f7e65097ea4facdba994ee51d751705a.r2.cloudflarestorage.com`,
signed with `aws4fetch`.

### Workflow: staging first

1. Edit `content/`, then run `npm run check`.
2. Run `npm run publish -- --env staging --dry-run` and read the plan. Open
   `.out/staging/` if you want to see the files.
3. Publish to staging:
   `R2_ACCESS_KEY_ID=… R2_SECRET_ACCESS_KEY=… npm run publish -- --env staging`.
4. Check a staging build of the app. It reads `latest.json` from the staging
   bucket, and premium audio plays through the staging Worker.
5. Publish the same commit to production with `--env production`.
6. Run `npm run build` and commit `assets/catalog/bundled.json`, so the next
   app release bundles the same catalogue.

Versions count separately in each environment, so staging v5 and production
v3 can hold the same catalogue. Compare them by the hash.

Rolling back means `git revert`, then publishing again. That makes a new,
higher version with the old content. Media files are never deleted, so the
old keys are still there.
