import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/cbt/cbt_catalog.dart';
import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/courses/course_catalog.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/content_tags.dart';
import 'package:yournotalone/recovery/halt_screen.dart';
import 'package:yournotalone/sleep/sleep_catalog.dart';
import 'package:yournotalone/stress/stress_catalog.dart';

/// `content/` is the source of the catalogue; the Dart catalogues are a
/// frozen fallback. They no longer have to match field for field, but
/// everything built into the app that points at content by id (HALT,
/// toolkit links, native screens, courses) must still find it in the
/// bundled snapshot.
void main() {
  final snapshot = CatalogSnapshot.fromJson(
    jsonDecode(File(bundledCatalogAsset).readAsStringSync())
        as Map<String, dynamic>,
  )!;
  final byId = {for (final i in snapshot.items) i.id: i};

  test('deepContent is every item tagged intensity: deep', () {
    final raw =
        jsonDecode(File(bundledCatalogAsset).readAsStringSync())
            as Map<String, dynamic>;
    final deep = {
      for (final i in (raw['items'] as List).cast<Map<String, dynamic>>())
        if ((i['tags'] as Map?)?['intensity'] == 'deep') i['id'] as String,
    };
    expect(deepContent, deep);
  });

  test('is the bundled copy, in a format this build reads', () {
    expect(snapshot.version, 0);
    expect(snapshot.hash, hasLength(16));
  });

  test('still has every built-in item, as the same kind', () {
    for (final item in builtInContentIndex) {
      expect(byId[item.id]?.kind, item.kind, reason: item.id);
    }
  });

  test('has what the app links to by id', () {
    final linked = [
      for (final t in haltMeditationTitles) 'meditation:$t',
      for (final t in haltSoundTitles) 'sound:$t',
      'meditation:$sleepMeditationTitle',
      'breathing:$sleepBreathingTitle',
      'meditation:$stressMeditationTitle',
      'breathing:$stressBreathingTitle',
      for (final id in const [
        'sound:Rainfall',
        'sound:Ocean waves',
        'sound:Deep focus',
      ])
        id,
    ];
    for (final id in linked) {
      expect(byId, contains(id), reason: id);
    }
  });

  test('every native tool names a screen this build has', () {
    for (final item in snapshot.items) {
      if (item.bodyType != 'native') continue;
      expect(screenFor(item), isNotNull, reason: item.id);
    }
    for (final t in [...cbtTools, ...sleepTools, ...stressTools]) {
      // A tool with a guard hands on to an item listed under its own name.
      if (t.guard != null) continue;
      expect(byId['tool:${t.title}']?.bodyType, 'native', reason: t.title);
    }
  });

  test('still has every built-in course and the days it lists', () {
    final ids = {for (final c in snapshot.courses) c.id};
    for (final c in builtInCourses) {
      expect(ids, contains(c.id));
    }
    for (final c in snapshot.courses) {
      for (final day in c.days) {
        expect(byId, contains(day), reason: '${c.id}: $day');
      }
    }
  });

  test('falls back to English for a locale with no reviewed copy', () {
    final s = snapshot.items.first;
    expect(s.textFor('fr').title, s.textFor('en').title);
  });

  test('reads a snapshot with fields it doesn\'t know', () {
    // New fields arrive without a format bump (backgrounds did), so an
    // older build must skip what it doesn't understand.
    final json =
        jsonDecode(File(bundledCatalogAsset).readAsStringSync())
            as Map<String, dynamic>;
    final item = (json['items'] as List).first as Map<String, dynamic>;
    final read = CatalogSnapshot.fromJson({
      ...json,
      'sparkles': {'any': 'thing'},
      'items': [
        {...item, 'background': 'dusk-waves', 'sparkles': true},
        ...(json['items'] as List).skip(1),
      ],
    })!;
    expect(read.items, hasLength(snapshot.items.length));
    expect(read.items.first.id, snapshot.items.first.id);
  });

  test('ignores a snapshot in a newer format', () {
    expect(
      CatalogSnapshot.fromJson({
        'format': catalogFormat + 1,
        'version': 9,
        'hash': 'x',
        'items': const [],
        'courses': const [],
      }),
      isNull,
    );
  });
}
