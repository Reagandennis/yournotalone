/// Turns a [CatalogSnapshot] into what the screens use — [ContentItem]s
/// that open the right screen, and [Course]s — and holds the one in use.
///
/// Off unless the app is built with `--dart-define=CATALOG_SNAPSHOT=true`;
/// until then [contentIndex] and [courses] come from the Dart catalogues,
/// exactly as before.
library;

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../cbt/cbt_catalog.dart';
import '../courses/course_catalog.dart';
import '../discover/content_index.dart';
import '../journal/new_entry.dart';
import '../meditation/breathing_screen.dart';
import '../meditation/meditation_catalog.dart';
import '../meditation/meditation_screen.dart';
import '../recovery/halt_screen.dart';
import '../recovery/insights_screen.dart';
import '../recovery/milestones_screen.dart';
import '../recovery/recovery_screen.dart';
import '../recovery/tape_forward_screen.dart';
import '../sleep/sleep_catalog.dart';
import '../sounds/player_screen.dart';
import '../sounds/sounds_catalog.dart';
import '../stress/stress_catalog.dart';
import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_content.dart';
import '../toolkit/toolkit_lesson_screen.dart';
import 'catalog_snapshot.dart';

const catalogSnapshotEnabled = bool.fromEnvironment('CATALOG_SNAPSHOT');

/// The language content is shown in. English until the UI itself is
/// translated, so a screen never mixes two languages.
const contentLocale = 'en';

/// The key a `native` item uses to name its screen: the tool's title,
/// lower-case and hyphenated ("Awake at 3am?" → `awake-at-3am`).
String screenKey(String title) => title
    .toLowerCase()
    .replaceAll(RegExp(r"['’]"), '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

/// Recovery screens built into the app, by the key content uses.
final _recoveryScreens = <String, WidgetBuilder>{
  'halt': (_) => const HaltScreen(),
  'tape-forward': (_) => const TapeForwardScreen(),
  'milestones': (_) => const MilestonesScreen(),
  'trigger-insights': (_) => const TriggerInsightsScreen(),
  'recovery-hub': (_) => const RecoveryScreen(),
};

final _tools = {
  for (final t in [...cbtTools, ...sleepTools, ...stressTools])
    screenKey(t.title): t,
};

/// The screen [item] opens, or null when this build can't show it (a
/// screen it doesn't have, a field it doesn't understand) — such items are
/// left out rather than shown as tiles that do nothing.
WidgetBuilder? screenFor(CatalogItem item) {
  final t = item.textFor(contentLocale);
  final body = item.body;
  try {
    switch (item.bodyType) {
      case 'breathing':
        final pattern = BreathPattern(
          t.title,
          t.blurb,
          item.accent,
          inhale: body['inhale'] as int,
          holdIn: body['holdIn'] as int,
          exhale: body['exhale'] as int,
          holdOut: body['holdOut'] as int,
          premium: item.premium,
        );
        return (_) => BreathingScreen(pattern: pattern);
      case 'meditation':
        final at = (body['promptAt'] as List).cast<num>();
        final meditation = Meditation(
          t.title,
          t.blurb,
          item.minutes!,
          item.icon,
          item.accent,
          premium: item.premium,
          prompts: [
            for (var i = 0; i < at.length; i++)
              (at[i].toDouble(), t.prompts[i]),
          ],
          narration: body['narration'] as String?,
        );
        return (_) => MeditationScreen(meditation: meditation);
      case 'sound':
        final sound = Sound(
          t.title,
          t.blurb,
          item.icon,
          SoundCategory.values.byName(body['category'] as String),
          body['audio'] as String,
          premium: item.premium,
          waveFreq: (body['waveFreq'] as num).toDouble(),
          waveSpeed: body['waveSpeed'] as int,
          waveHeight: (body['waveHeight'] as num).toDouble(),
          pulse: body['pulse'] as bool,
        );
        return (_) => PlayerScreen(sound: sound);
      case 'lesson':
        final lesson = ToolkitLesson(
          title: t.title,
          blurb: t.blurb,
          minutes: item.minutes!,
          art: ToolkitArtKind.values.byName(body['art'] as String),
          paragraphs: t.paragraphs,
          premium: item.premium,
        );
        return (_) => ToolkitLessonScreen(lesson: lesson, accent: item.accent);
      case 'native':
        final key = body['screen'] as String;
        return item.kind == ContentKind.tool
            ? _tools[key]?.open
            : _recoveryScreens[key];
    }
  } catch (e) {
    debugPrint('Can\'t show ${item.id}: $e');
  }
  return null;
}

/// [snapshot]'s items as the index lists them.
List<ContentItem> contentItemsFrom(CatalogSnapshot snapshot) => [
  for (final item in snapshot.items) ?_contentItem(item),
];

ContentItem? _contentItem(CatalogItem item) {
  final t = item.textFor(contentLocale);
  void Function(BuildContext) open;
  if (item.bodyType == 'prompt') {
    open = (context) =>
        openNewJournalEntry(context, title: t.title, content: t.seed);
  } else {
    final screen = screenFor(item);
    if (screen == null) return null;
    open = (context) =>
        Navigator.of(context).push(MaterialPageRoute(builder: screen));
  }
  return ContentItem(
    kind: item.kind,
    title: t.title,
    blurb: t.blurb,
    icon: item.icon,
    accent: item.accent,
    premium: item.premium,
    open: open,
    minutes: item.minutes,
    area: t.area,
    needs: item.needs,
    dayParts: item.dayParts,
    addedOn: item.addedOn,
  );
}

/// [snapshot]'s courses, leaving out any with a day that isn't in [items]
/// (a course with a hole in it can't be followed).
List<Course> coursesFrom(CatalogSnapshot snapshot, List<ContentItem> items) {
  final ids = {for (final i in items) i.id};
  return [
    for (final c in snapshot.courses)
      if (c.days.every(ids.contains))
        Course(
          id: c.id,
          title: c.textFor(contentLocale).title,
          blurb: c.textFor(contentLocale).blurb,
          accent: c.accent,
          icon: c.icon,
          need: c.need,
          days: [
            for (var i = 0; i < c.days.length; i++)
              CourseDay(c.days[i], c.textFor(contentLocale).notes[i]),
          ],
        ),
  ];
}

/// The catalogue the screens read, when it comes from a snapshot.
class ContentCatalog {
  ContentCatalog._();

  static final instance = ContentCatalog._();

  CatalogSnapshot? _snapshot;
  List<ContentItem>? _items;
  List<Course>? _courses;

  /// Null means "use the Dart catalogues".
  List<ContentItem>? get items => _items;
  List<Course>? get courses => _courses;
  int? get version => _snapshot?.version;

  /// Loads the bundled snapshot when the flag is on. Never throws: on any
  /// problem the Dart catalogues stay in use.
  Future<void> load() async {
    if (!catalogSnapshotEnabled) return;
    try {
      use(await CatalogSnapshot.bundled());
    } catch (error, stackTrace) {
      debugPrint('Catalogue snapshot unavailable: $error');
      await Sentry.captureException(error, stackTrace: stackTrace);
    }
  }

  void use(CatalogSnapshot snapshot) {
    final items = contentItemsFrom(snapshot);
    _snapshot = snapshot;
    _items = items;
    _courses = coursesFrom(snapshot, items);
  }

  @visibleForTesting
  void reset() {
    _snapshot = null;
    _items = null;
    _courses = null;
  }
}
