import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/cbt/cbt_catalog.dart';
import 'package:yournotalone/cbt/cbt_content.dart';
import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/courses/course_catalog.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/content_tags.dart';
import 'package:yournotalone/journal/journal_prompts.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/recovery/recovery_screen.dart';
import 'package:yournotalone/sleep/sleep_catalog.dart';
import 'package:yournotalone/sleep/sleep_content.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';
import 'package:yournotalone/stress/stress_catalog.dart';
import 'package:yournotalone/stress/stress_content.dart';

/// Until the app reads its catalogue from the snapshot, the Dart
/// catalogues and `content/` must say the same thing. If this fails after
/// a content change in Dart, re-run the export and rebuild:
///
///   flutter test tool/export_content_test.dart
///   (cd tools/content && npm run build)
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

  test('lists every index item, in the same order', () {
    expect(
      [for (final i in snapshot.items) i.id],
      [for (final i in builtInContentIndex) i.id],
    );
  });

  test('matches every index item field for field', () {
    for (final item in builtInContentIndex) {
      final s = byId[item.id]!;
      final en = s.textFor('en');
      final reason = item.id;
      expect(s.kind, item.kind, reason: reason);
      expect(en.title, item.title, reason: reason);
      expect(en.blurb, item.blurb, reason: reason);
      expect(en.area, item.area, reason: reason);
      expect(s.icon, item.icon, reason: reason);
      expect(s.accent, item.accent, reason: reason);
      expect(s.premium, item.premium, reason: reason);
      expect(s.minutes, item.minutes, reason: reason);
      expect(s.needs, item.needs, reason: reason);
      expect(s.dayParts, item.dayParts, reason: reason);
      expect(s.addedOn, item.addedOn, reason: reason);
    }
  });

  test('carries each kind\'s body', () {
    for (final p in breathPatterns) {
      final s = byId['breathing:${p.title}']!;
      expect(s.body, {
        'type': 'breathing',
        'inhale': p.inhale,
        'holdIn': p.holdIn,
        'exhale': p.exhale,
        'holdOut': p.holdOut,
      });
    }

    void meditation(String id, Meditation m) {
      final s = byId[id]!;
      expect(s.bodyType, 'meditation', reason: id);
      expect(s.body['promptAt'], [for (final (at, _) in m.prompts) at]);
      expect(s.textFor('en').prompts, [for (final (_, l) in m.prompts) l]);
      expect(s.body['narration'], m.narration, reason: id);
    }

    for (final m in meditations) {
      meditation('meditation:${m.title}', m);
    }
    meditation('recovery:${urgeSurfMeditation.title}', urgeSurfMeditation);

    for (final sound in soundsCatalog) {
      final s = byId['sound:${sound.title}']!;
      expect(s.body, {
        'type': 'sound',
        'category': sound.category.name,
        'audio': sound.asset,
        'loop': true,
        'waveFreq': sound.waveFreq,
        'waveSpeed': sound.waveSpeed,
        'waveHeight': sound.waveHeight,
        'pulse': sound.pulse,
      });
    }

    for (final p in journalPrompts) {
      final s = byId['prompt:${p.title}']!;
      expect(s.body, {'type': 'prompt', 'group': p.group});
      expect(s.textFor('en').seed, p.seed);
    }

    for (final l in [...cbtLessons, ...sleepLessons, ...stressLessons]) {
      final s = byId['lesson:${l.title}']!;
      expect(s.body, {'type': 'lesson', 'art': l.art.name});
      expect(s.textFor('en').paragraphs, l.paragraphs);
    }

    for (final t in [...cbtTools, ...sleepTools, ...stressTools]) {
      final s = byId['tool:${t.title}'];
      // A tool with a guard hands on to an item listed under its own name.
      if (t.guard != null) {
        expect(s, isNull, reason: t.title);
        continue;
      }
      expect(s!.bodyType, 'native');
      expect(s.body['art'], t.art.name);
      expect(s.textFor('en').meta, t.meta);
    }
  });

  test('matches the courses', () {
    expect(
      [for (final c in snapshot.courses) c.id],
      [for (final c in builtInCourses) c.id],
    );
    for (final c in builtInCourses) {
      final s = snapshot.courses.firstWhere((x) => x.id == c.id);
      final en = s.textFor('en');
      expect(en.title, c.title);
      expect(en.blurb, c.blurb);
      expect(s.icon, c.icon);
      expect(s.accent, c.accent);
      expect(s.need, c.need);
      expect(s.days, [for (final d in c.days) d.itemId]);
      expect(en.notes, [for (final d in c.days) d.note]);
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
