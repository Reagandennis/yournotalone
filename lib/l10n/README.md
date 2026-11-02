# App strings and languages

Every word the app shows (apart from content — see below) lives in the ARB
files in this folder. English, `app_en.arb`, is the source; `flutter gen-l10n`
(run by `flutter pub get`, `flutter run` and `flutter build`) turns them into
`AppLocalizations` in `app_localizations*.dart`. Don't edit those by hand.

| File              | Language                  | Register             |
|-------------------|---------------------------|----------------------|
| `app_en.arb`      | English (source)          | —                    |
| `app_fr.arb`      | French                    | *tu*                 |
| `app_de.arb`      | German                    | *du*                 |
| `app_es.arb`      | Spanish (neutral)         | *tú*                 |
| `app_zh.arb`      | Chinese, Simplified       | 你 (not 您)          |
| `app_zh_Hans.arb` | Chinese, Simplified script | only `@@locale`: everything comes from `app_zh.arb` |

`app_zh_Hans.arb` is there because gen-l10n needs the plain `zh` file as the
fallback for a script variant. The app offers Chinese as `zh-Hans`.
Traditional Chinese (`zh-Hant`, Taiwan, Hong Kong) isn't offered yet; those
phones get the next language on their list, else English.

## Using a string

```dart
import '../l10n/l10n.dart';

Text(context.l10n.journalEmptyTitle)
```

`context.l10n` falls back to English where there's no app-level
`Localizations` (a widget test pumping a bare `MaterialApp`). Code with no
`BuildContext` — notifications, background work — uses `currentL10n()`.

## Adding or changing a string

1. Add it to `app_en.arb` with a key named after where it's used
   (`sleepDiarySaveNight`, not `saveButton2`) and an `@key` entry whose
   `description` tells a translator where it appears, what it means and any
   length limit. That description is all the context they get.
2. Text built from values uses placeholders, and counts use ICU plurals, so
   every language can order and inflect the sentence its own way:

   ```json
   "rhythmDaysLeft": "{count, plural, =1{1 day left} other{{count} days left}}",
   "@rhythmDaysLeft": {
     "description": "Under the weekly goal on Home.",
     "placeholders": { "count": { "type": "int" } }
   }
   ```

   Never glue a sentence together from separately translated pieces.
3. Add the same key to every other `app_*.arb` (except `app_zh_Hans.arb`). If
   you can't translate it yet, copy the English: it shows in English until a
   translator gets to it, and the reviewer will see it.
4. `flutter test test/l10n_test.dart` checks that every ARB has exactly the
   keys of `app_en.arb`, with the same placeholders, and that every English
   string has a description.

Not in these files, on purpose: content (meditations, lessons, prompts,
tools' copy in `*_content.dart` / `*_catalog.dart` and the `content/` YAML,
which has its own per-locale `text` and review flow), the legal documents,
the country-keyed crisis helplines, brand names, prices from the store, and
ids, analytics names and anything saved to the device or the database.

## Drafts and review

The French, German, Spanish and Chinese files are drafts. Wording about mental
health — and crisis wording above all — has to be read by a fluent person
before it ships: a translation that is merely correct can still sound cold,
clinical or alarming.

`reviewedLocales` in `l10n.dart` lists the languages that have been reviewed.

- A **release build** offers only those (and English), whatever the phone's
  language.
- A **debug or profile build** offers every drafted language.
- A release build made with `--dart-define=L10N_DRAFTS=true` offers every
  drafted language too — use it for testers and reviewers:

  ```sh
  flutter build apk --dart-define=L10N_DRAFTS=true
  flutter build ipa --dart-define=L10N_DRAFTS=true
  ```

Testers can then pick the language under Settings → Language, or set their
phone to it.

### Reviewing a language

1. Build with `L10N_DRAFTS=true` and use the app in that language from
   onboarding to a therapy booking, and especially the crisis screen and
   anything about feelings, sleep and recovery.
2. Edit the language's ARB file directly. Keep the placeholders (`{name}`,
   `{count, plural, …}`) as they are; translate the text around them and
   inside the plural branches. Keep the register in the table above.
3. Check layouts at a small phone size: German runs long, and Chinese is
   taller.
4. When the whole file has been read, add the tag (`fr`, `de`, `es`,
   `zh-Hans`) to `reviewedLocales` in `l10n.dart`. Release builds offer it
   from then on.
