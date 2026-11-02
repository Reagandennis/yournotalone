/// Turns a [CatalogSnapshot] into what the screens use — [ContentItem]s
/// that open the right screen, and [Course]s — and holds the one in use.
///
/// Off unless the app is built with `--dart-define=CATALOG_SNAPSHOT=true`;
/// until then [contentIndex] and [courses] come from the Dart catalogues,
/// exactly as before.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Asset paths built into this app, once [ContentCatalog.load] has read
/// them; null means "don't check" (tests).
Set<String>? _bundledAssets;

/// Whether [path] can be played: until audio is downloaded on demand,
/// only files shipped inside the app can.
bool _playable(String path) => _bundledAssets?.contains(path) ?? true;

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
          // Without its recording a meditation still runs on its text.
          narration: switch (body['narration']) {
            final String path when _playable(path) => path,
            _ => null,
          },
        );
        return (_) => MeditationScreen(meditation: meditation);
      case 'sound':
        // A sound published after this build can't play yet: leave it out.
        if (!_playable(body['audio'] as String)) return null;
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

/// Where published catalogues are fetched from.
const catalogBaseUrl = String.fromEnvironment(
  'CATALOG_BASE_URL',
  defaultValue: 'https://database.techgetafrica.com',
);

/// Whether [version] (`1.2.0`) is at least [minimum].
bool appVersionAtLeast(String version, String minimum) {
  List<int> parts(String v) => [
    for (final p in v.split('+').first.split('.')) int.tryParse(p) ?? 0,
  ];
  final a = parts(version), b = parts(minimum);
  for (var i = 0; i < 3; i++) {
    final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return true;
}

/// The catalogue the screens read, when it comes from a snapshot.
///
/// At launch it uses the newest of the bundled snapshot and the last one
/// downloaded, then checks in the background for a newer published one.
/// A download takes effect at the next launch, so nothing changes under
/// someone mid-session.
class ContentCatalog {
  ContentCatalog._([this._client, Future<String> Function()? appVersion])
    : _appVersion = appVersion ?? _platformVersion;

  static final instance = ContentCatalog._();

  @visibleForTesting
  factory ContentCatalog.forTest({
    required http.Client client,
    required String appVersion,
  }) => ContentCatalog._(client, () async => appVersion);

  static Future<String> _platformVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  static const _cacheKey = 'catalog.snapshot';

  final http.Client? _client;
  final Future<String> Function() _appVersion;

  CatalogSnapshot? _snapshot;
  List<ContentItem>? _items;
  List<Course>? _courses;

  /// Null means "use the Dart catalogues".
  List<ContentItem>? get items => _items;
  List<Course>? get courses => _courses;
  int? get version => _snapshot?.version;

  /// Picks the snapshot to use when the flag is on, then looks for a newer
  /// one in the background. Never throws: on any problem the bundled
  /// snapshot, or failing that the Dart catalogues, stay in use.
  Future<void> load() async {
    if (!catalogSnapshotEnabled) return;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _bundledAssets = manifest.listAssets().toSet();
      await loadFrom(await CatalogSnapshot.bundled());
    } catch (error, stackTrace) {
      debugPrint('Catalogue snapshot unavailable: $error');
      await Sentry.captureException(error, stackTrace: stackTrace);
    }
    unawaited(refresh());
  }

  /// Uses [bundled], or the downloaded snapshot if that's newer.
  @visibleForTesting
  Future<void> loadFrom(CatalogSnapshot bundled) async {
    var best = bundled;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final cached = CatalogSnapshot.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        if (cached != null && cached.version > bundled.version) best = cached;
      }
    } catch (e) {
      debugPrint('Downloaded catalogue unreadable, using the bundled one: $e');
    }
    use(best);
  }

  /// Downloads the published catalogue if it's newer than the one in use
  /// and this app is new enough to read it. Returns whether it did. Never
  /// throws.
  Future<bool> refresh() async {
    final client = _client ?? http.Client();
    try {
      final base = Uri.parse(catalogBaseUrl);
      final latest = await client
          .get(base.resolve('catalog/latest.json'))
          .timeout(const Duration(seconds: 10));
      if (latest.statusCode != 200) return false;
      final pointer = jsonDecode(latest.body) as Map<String, dynamic>;
      final version = pointer['version'] as int;
      final path = pointer['path'] as String;
      final minApp = pointer['minApp'] as String? ?? '0.0.0';
      if (version <= (_snapshot?.version ?? -1)) return false;
      if (!appVersionAtLeast(await _appVersion(), minApp)) return false;

      final res = await client
          .get(base.resolve(path))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return false;
      final json =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final snapshot = CatalogSnapshot.fromJson(json);
      // The file named in latest.json, whole and in a format we read.
      if (snapshot == null ||
          snapshot.version != version ||
          !path.endsWith('-${snapshot.hash}.json')) {
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, utf8.decode(res.bodyBytes));
      return true;
    } catch (e) {
      debugPrint('Catalogue check failed: $e');
      return false;
    } finally {
      if (_client == null) client.close();
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

@visibleForTesting
set bundledAssetsForTest(Set<String>? assets) => _bundledAssets = assets;
