import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/cbt/cbt_catalog.dart';
import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/courses/course_catalog.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/meditation/breathing_screen.dart';
import 'package:yournotalone/meditation/meditation_screen.dart';
import 'package:yournotalone/recovery/halt_screen.dart';
import 'package:yournotalone/sleep/sleep_catalog.dart';
import 'package:yournotalone/sounds/player_screen.dart';
import 'package:yournotalone/stress/stress_catalog.dart';
import 'package:yournotalone/toolkit/toolkit_lesson_screen.dart';

Map<String, dynamic> _bundledJson() =>
    jsonDecode(File(bundledCatalogAsset).readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final snapshot = CatalogSnapshot.fromJson(_bundledJson())!;
  final fromSnapshot = contentItemsFrom(snapshot);

  tearDown(() {
    // Leave the catalogue as the run started: a run with
    // CATALOG_SNAPSHOT=true begins with the snapshot in use.
    if (catalogSnapshotEnabled) {
      ContentCatalog.instance.use(snapshot);
    } else {
      ContentCatalog.instance.reset();
    }
  });

  test('builds an index item from every snapshot item, field for field', () {
    expect(
      [for (final i in fromSnapshot) i.id],
      [for (final i in snapshot.items) i.id],
    );
    final byId = {for (final i in snapshot.items) i.id: i};
    for (final s in fromSnapshot) {
      final d = byId[s.id]!;
      final en = d.textFor('en');
      expect(
        (
          s.kind,
          s.title,
          s.blurb,
          s.icon,
          s.accent,
          s.premium,
          s.minutes,
          s.area,
          _names(s.needs),
          _names(s.dayParts),
          s.addedOn,
        ),
        (
          d.kind,
          en.title,
          en.blurb,
          d.icon,
          d.accent,
          d.premium,
          d.minutes,
          en.area,
          _names(d.needs),
          _names(d.dayParts),
          d.addedOn,
        ),
        reason: s.id,
      );
    }
  });

  test('builds the snapshot\'s courses', () {
    final built = coursesFrom(snapshot, fromSnapshot);
    expect(
      [for (final c in built) c.id],
      [for (final c in snapshot.courses) c.id],
    );
    for (final s in built) {
      final d = snapshot.courses.firstWhere((c) => c.id == s.id);
      final en = d.textFor('en');
      expect(
        (s.title, s.blurb, s.icon, s.accent, s.need),
        (en.title, en.blurb, d.icon, d.accent, d.need),
      );
      expect(
        [for (final day in s.days) (day.itemId, day.note)],
        [for (var i = 0; i < d.days.length; i++) (d.days[i], en.notes[i])],
      );
    }
  });

  testWidgets('each item opens the screen the Dart catalogue opens', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    final byId = {for (final i in snapshot.items) i.id: i};
    Widget screen(String id) => screenFor(byId[id]!)!(context);

    final breathing = screen('breathing:4-7-8 calm') as BreathingScreen;
    expect([breathing.pattern.inhale, breathing.pattern.holdIn], [4, 7]);
    expect(breathing.pattern.exhale, 8);

    final meditation = screen('meditation:Body scan') as MeditationScreen;
    expect(meditation.meditation.minutes, 12);
    expect(meditation.meditation.prompts.first.$2, startsWith('Lie down'));

    final urgeSurf = screen('recovery:Urge surfing');
    expect(urgeSurf, isA<MeditationScreen>());

    final sound = screen('sound:Rainfall') as PlayerScreen;
    expect(sound.sound.asset, 'assets/sounds/rainfall.m4a');

    expect(screen('lesson:The 20-minute rule'), isA<ToolkitLessonScreen>());
    expect(screen('recovery:HALT check'), isA<HaltScreen>());

    for (final t in [...cbtTools, ...sleepTools, ...stressTools]) {
      if (t.guard != null) continue;
      expect(
        screen('tool:${t.title}').runtimeType,
        t.open(context).runtimeType,
        reason: t.title,
      );
    }
  });

  test('leaves out an item whose screen this build lacks, and its course', () {
    final json = _bundledJson();
    final tool = (json['items'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((i) => i['id'] == 'tool:Wind-down plan');
    (tool['body'] as Map<String, dynamic>)['screen'] = 'from-the-future';
    final edited = CatalogSnapshot.fromJson(json)!;
    final items = contentItemsFrom(edited);

    expect(items.any((i) => i.id == 'tool:Wind-down plan'), isFalse);
    expect(items, hasLength(fromSnapshot.length - 1));
    // sleep7 starts with that tool, so it can't be followed.
    expect([
      for (final c in coursesFrom(edited, items)) c.id,
    ], isNot(contains('sleep7')));
  });

  test('the index and courses switch to the snapshot when one is used', () {
    ContentCatalog.instance.reset();
    expect(identical(contentIndex, builtInContentIndex), isTrue);
    expect(identical(courses, builtInCourses), isTrue);

    ContentCatalog.instance.use(snapshot);
    expect(identical(contentIndex, builtInContentIndex), isFalse);
    expect(contentIndex, hasLength(snapshot.items.length));
    expect(courses, hasLength(snapshot.courses.length));
  });

  test('screen keys match the tool titles', () {
    expect(screenKey('Awake at 3am?'), 'awake-at-3am');
    expect(screenKey('What\'s in your hands'), 'whats-in-your-hands');
  });
}

/// Sets compare by identity inside a record; sorted names compare by value.
String _names(Set<Enum> values) =>
    ([for (final v in values) v.name]..sort()).join(',');
