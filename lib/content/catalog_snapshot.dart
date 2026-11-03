/// The catalogue as data: the snapshot `tools/content` builds from
/// `content/` (see docs/backend-design.md §4). The app bundles one at
/// `assets/catalog/bundled.json`; later a newer one can be downloaded.
///
/// The screens read it only in a build with `CATALOG_SNAPSHOT=true` (see
/// `content_catalog.dart`); otherwise the Dart catalogues are what they
/// use, and `test/content_snapshot_test.dart` checks the two say exactly
/// the same thing in English.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backgrounds/background_spec.dart';
import '../brand.dart';
import '../cbt/cbt_content.dart';
import '../discover/content_index.dart';
import '../l10n/l10n.dart';
import '../sleep/sleep_content.dart';
import '../stress/stress_content.dart';
import 'content_icons.dart';

/// The snapshot format this build can read. A newer one is ignored and the
/// app keeps what it has.
const catalogFormat = 1;

const bundledCatalogAsset = 'assets/catalog/bundled.json';

/// Accents content can name; anything else arrives as `#AARRGGBB`.
const contentAccents = <String, Color>{
  'red': Pillars.red,
  'blue': Pillars.blue,
  'black': Pillars.black,
  'yellow': Pillars.yellow,
  'cbt': cbtAccent,
  'sleep': sleepAccent,
  'stress': stressAccent,
};

Color _accent(String name) =>
    contentAccents[name] ?? Color(int.parse(name.substring(1), radix: 16));

IconData _icon(String name) => contentIcons[name] ?? Icons.auto_awesome_rounded;

/// One locale's copy of an item. Only the fields its kind uses are set.
class ItemText {
  const ItemText({
    required this.title,
    required this.blurb,
    this.area,
    this.meta,
    this.prompts = const [],
    this.paragraphs = const [],
    this.seed,
    this.reviewed = true,
  });

  factory ItemText.fromJson(Map<String, dynamic> json) => ItemText(
    title: json['title'] as String,
    blurb: json['blurb'] as String,
    area: json['area'] as String?,
    meta: json['meta'] as String?,
    prompts: [...?(json['prompts'] as List?)?.cast<String>()],
    paragraphs: [...?(json['paragraphs'] as List?)?.cast<String>()],
    seed: json['seed'] as String?,
    reviewed: _reviewed(json),
  );

  final String title;
  final String blurb;
  final String? area;
  final String? meta;
  final List<String> prompts;
  final List<String> paragraphs;
  final String? seed;

  /// Whether a fluent reader has checked this translation. English, the
  /// source, always is.
  final bool reviewed;
}

/// A translation's `reviewed` flag. Snapshots from before drafts were
/// published carried only reviewed translations, without the flag.
bool _reviewed(Map<String, dynamic> json) => json['reviewed'] as bool? ?? true;

/// Which locale's copy to show someone reading [locale], given which
/// translations exist and whether each is [reviewed]: theirs if it has
/// been reviewed, or with [drafts] on if there's one at all; otherwise
/// English.
String pickLocale(
  Map<String, bool> reviewed,
  String locale, {
  bool drafts = false,
}) => switch (reviewed[locale]) {
  final ok? when ok || drafts => locale,
  _ => 'en',
};

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.kind,
    required this.order,
    required this.premium,
    required this.icon,
    required this.accent,
    required this.needs,
    required this.dayParts,
    required this.text,
    required this.body,
    this.minutes,
    this.addedOn,
    this.background,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    final tags = json['tags'] as Map<String, dynamic>;
    final needs = Need.values.asNameMap();
    final dayParts = DayPart.values.asNameMap();
    final added = json['addedOn'] as String?;
    return CatalogItem(
      id: json['id'] as String,
      kind: ContentKind.values.byName(json['kind'] as String),
      order: json['order'] as int,
      premium: json['premium'] as bool,
      minutes: json['minutes'] as int?,
      addedOn: added == null ? null : DateTime.parse(added),
      icon: _icon(json['icon'] as String),
      accent: _accent(json['accent'] as String),
      // Unknown names are dropped, so a newer vocabulary doesn't break an
      // older app.
      needs: {for (final n in tags['needs'] as List) ?needs[n]},
      dayParts: {for (final d in tags['dayParts'] as List) ?dayParts[d]},
      text: {
        for (final MapEntry(:key, :value)
            in (json['text'] as Map<String, dynamic>).entries)
          key: ItemText.fromJson(value as Map<String, dynamic>),
      },
      body: json['body'] as Map<String, dynamic>,
      background: json['background'] as String?,
    );
  }

  final String id;
  final ContentKind kind;
  final int order;
  final bool premium;
  final int? minutes;
  final DateTime? addedOn;
  final IconData icon;
  final Color accent;
  final Set<Need> needs;
  final Set<DayPart> dayParts;
  final Map<String, ItemText> text;

  /// Kind-specific: breathing timings, meditation prompt times, a sound's
  /// file and wave, a native screen's key. `type` says which.
  final Map<String, dynamic> body;

  String get bodyType => body['type'] as String;

  /// The id of the background it opens with, if not its kind's default.
  final String? background;

  /// The locale [textFor] shows for [locale] (see [pickLocale]).
  String localeFor(String locale, {bool drafts = false}) => pickLocale(
    {for (final MapEntry(:key, :value) in text.entries) key: value.reviewed},
    locale,
    drafts: drafts,
  );

  /// The copy for someone reading [locale]: theirs if reviewed (or if
  /// [drafts] is on), otherwise English.
  ItemText textFor(String locale, {bool drafts = false}) =>
      text[localeFor(locale, drafts: drafts)]!;
}

class CourseText {
  const CourseText({
    required this.title,
    required this.blurb,
    required this.notes,
    this.reviewed = true,
  });

  factory CourseText.fromJson(Map<String, dynamic> json) => CourseText(
    title: json['title'] as String,
    blurb: json['blurb'] as String,
    notes: (json['notes'] as List).cast<String>(),
    reviewed: _reviewed(json),
  );

  final String title;
  final String blurb;

  /// One per day.
  final List<String> notes;

  /// See [ItemText.reviewed].
  final bool reviewed;
}

class CatalogCourse {
  const CatalogCourse({
    required this.id,
    required this.order,
    required this.icon,
    required this.accent,
    required this.need,
    required this.days,
    required this.text,
  });

  factory CatalogCourse.fromJson(Map<String, dynamic> json) => CatalogCourse(
    id: json['id'] as String,
    order: json['order'] as int,
    icon: _icon(json['icon'] as String),
    accent: _accent(json['accent'] as String),
    need: Need.values.byName(json['need'] as String),
    days: (json['days'] as List).cast<String>(),
    text: {
      for (final MapEntry(:key, :value)
          in (json['text'] as Map<String, dynamic>).entries)
        key: CourseText.fromJson(value as Map<String, dynamic>),
    },
  );

  final String id;
  final int order;
  final IconData icon;
  final Color accent;
  final Need need;

  /// Item ids, one per day.
  final List<String> days;
  final Map<String, CourseText> text;

  /// See [CatalogItem.localeFor].
  String localeFor(String locale, {bool drafts = false}) => pickLocale(
    {for (final MapEntry(:key, :value) in text.entries) key: value.reviewed},
    locale,
    drafts: drafts,
  );

  /// See [CatalogItem.textFor].
  CourseText textFor(String locale, {bool drafts = false}) =>
      text[localeFor(locale, drafts: drafts)]!;
}

/// Where a published audio file lives. Public files are at
/// `<public base>/<key>`; premium ones are fetched through a signed link
/// from the Worker.
class MediaRef {
  const MediaRef({
    required this.key,
    required this.sha256,
    required this.bytes,
    required this.premium,
  });

  factory MediaRef.fromJson(Map<String, dynamic> json) => MediaRef(
    key: json['key'] as String,
    sha256: json['sha256'] as String,
    bytes: json['bytes'] as int,
    premium: json['access'] == 'premium',
  );

  final String key;
  final String sha256;
  final int bytes;
  final bool premium;
}

class CatalogSnapshot {
  const CatalogSnapshot({
    required this.version,
    required this.hash,
    required this.items,
    required this.courses,
    this.backgrounds = const [],
    this.media = const {},
  });

  /// Null when the file is in a format this build can't read.
  static CatalogSnapshot? fromJson(Map<String, dynamic> json) {
    if (json['format'] != catalogFormat) return null;
    return CatalogSnapshot(
      version: json['version'] as int,
      hash: json['hash'] as String,
      items: [
        for (final i in json['items'] as List)
          CatalogItem.fromJson(i as Map<String, dynamic>),
      ],
      courses: [
        for (final c in json['courses'] as List)
          CatalogCourse.fromJson(c as Map<String, dynamic>),
      ],
      // Added without a format bump: older builds skip the field, and this
      // one skips any background it can't draw.
      backgrounds: [
        for (final b in (json['backgrounds'] as List?) ?? const [])
          ?BackgroundSpec.fromJson(
            _withoutUnreviewed(b as Map<String, dynamic>, l10nDraftsEnabled),
          ),
      ],
      media: {
        for (final MapEntry(key: id, value: refs)
            in ((json['media'] as Map<String, dynamic>?) ?? const {}).entries)
          id: {
            for (final MapEntry(key: role, value: ref)
                in (refs as Map<String, dynamic>).entries)
              role: MediaRef.fromJson(ref as Map<String, dynamic>),
          },
      },
    );
  }

  /// [json] with only the translations a build with [drafts] as given may
  /// show. A background keeps only its titles by locale, so the gate is
  /// applied here, before they're read.
  static Map<String, dynamic> _withoutUnreviewed(
    Map<String, dynamic> json,
    bool drafts,
  ) {
    final text = json['text'];
    if (drafts || text is! Map<String, dynamic>) return json;
    return {
      ...json,
      'text': {
        for (final MapEntry(:key, :value) in text.entries)
          if (key == 'en' || value is! Map<String, dynamic> || _reviewed(value))
            key: value,
      },
    };
  }

  /// The copy built into the app.
  static Future<CatalogSnapshot> bundled() async {
    final raw = await rootBundle.loadString(bundledCatalogAsset);
    return fromJson(jsonDecode(raw) as Map<String, dynamic>)!;
  }

  /// 0 for the bundled copy; published catalogues count up from 1.
  final int version;
  final String hash;

  /// Published items, in list order.
  final List<CatalogItem> items;
  final List<CatalogCourse> courses;

  /// Animated backgrounds this build can draw, in list order.
  final List<BackgroundSpec> backgrounds;

  /// Published audio by item id, then role (`audio`, `narration`). Empty
  /// in the bundled copy, whose audio ships inside the app.
  final Map<String, Map<String, MediaRef>> media;
}
