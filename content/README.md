# Content

Everything the app offers, as data: one YAML file per item in `items/`, one
per course in `courses/`, and the allowed tags in `vocab.yaml`. Design:
`docs/backend-design.md` §4 and §8.

## For now the Dart catalogues are still the source of truth

The screens read the catalogues in `lib/` unless the app is built with
`--dart-define=CATALOG_SNAPSHOT=true`, and these files were exported from
them. Until the app switches over for good, change content in Dart and then
regenerate:

```
flutter test tool/export_content_test.dart   # Dart catalogues → content/
(cd tools/content && npm run build)          # content/ → assets/catalog/bundled.json
```

`test/content_snapshot_test.dart` fails if the two drift apart.

## Rules the checker enforces (`cd tools/content && npm run check`)

- **Never change an `id`.** Saves, course days and practice history point
  at it. To retitle an item, change `text.en.title` and keep the id. New
  items get a short slug id (`morning-reset`).
- `kind` is where the item is listed. `body.type` is what the item is:
  breathing, meditation, sound, prompt, lesson, or `native`. A `native`
  item is a screen built into the app and only gets its tags from here.
- Every item needs at least one need. Tags must come from `vocab.yaml`.
  Icons must come from `lib/content/content_icons.dart`.
- `order` sets the position in lists. Use gaps of 10 so there's room to
  slot items in later.
- `status` is `published`, `draft` or `retired`. Drafts and retired items
  are left out of the snapshot. A published course can't include a day
  that isn't published.
- Translations go under `text.fr`, `text.de`, `text.es` and
  `text.zh-Hans`. A translation is published only once it has
  `reviewed: true`. Until then the app shows English.
- A meditation needs one prompt line for each `promptAt` time, in every
  language.

## Backgrounds

`backgrounds/` holds the animated scenes behind the sound player and the
meditation and breathing screens (design: `docs/backend-design.md` §7).
Each one picks a code-drawn engine in the app (`waves`, `aurora`,
`particles` or `gradient`) and tunes it, so a new background is just a
file here: nothing is downloaded and it works offline.

```yaml
id: dusk-waves
status: published
order: 20
engine: waves
defaultFor: [sound]          # optional: kinds that open with it
params:
  palette: ["#5E8BDD", "#3764CD", "#1A2238"]   # 2–6 colours, back to front
  speed: 0.8                 # 1 is the engine's usual pace
  density: 1                 # 1 is its usual amount
  seed: 7                    # moves things around
  intensity: 0.8             # optional, 0–1
text:
  en:
    title: Dusk waves
```

- Keep palettes calm and low in contrast: the app draws them faintly over
  the page, and text sits on top.
- An item can prefer one with `background: <id>`; otherwise it gets its
  kind's `defaultFor`. A kind can have only one default.
- The export (`tool/export_content_test.dart`) keeps an item's
  `background:` line when it rewrites the file.

Publishing to R2 is covered in `tools/content/README.md`.
