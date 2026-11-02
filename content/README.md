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
- Three optional tags feed the recommendation safety rules (design §5) and
  exist only here, not in Dart (the export carries them over):
  - `intensity`: `gentle`, `moderate` or `deep`. Deep items dig into
    what's hard (worst-case writing, thought records).
  - `calmingSafe: true`: allowed straight after an awful or low check-in.
    Never on a `deep` item or one for `good`. Tag conservatively: breathing
    without long holds, grounding, soft sounds.
  - `support: true`: crisis and support content. Must be free; never
    ranked down.
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

Publishing to R2 is covered in `tools/content/README.md`.
