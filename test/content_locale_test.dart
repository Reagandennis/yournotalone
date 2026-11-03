import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/courses/course_catalog.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/l10n/l10n.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/meditation/meditation_screen.dart';

Map<String, dynamic> _bundledJson() =>
    jsonDecode(File(bundledCatalogAsset).readAsStringSync())
        as Map<String, dynamic>;

const _translations = ['fr', 'de', 'es', 'zh-Hans'];

/// The bundled snapshot with [edit] applied to the item [id]'s JSON.
CatalogSnapshot _withItem(String id, void Function(Map<String, dynamic>) edit) {
  final json = _bundledJson();
  for (final item in json['items'] as List) {
    if ((item as Map<String, dynamic>)['id'] == id) edit(item);
  }
  return CatalogSnapshot.fromJson(json)!;
}

void main() {
  final snapshot = CatalogSnapshot.fromJson(_bundledJson())!;

  tearDown(() {
    LocaleSetting.instance.value = null;
    debugDraftsOverride = null;
    if (catalogSnapshotEnabled) {
      ContentCatalog.instance.use(snapshot);
    } else {
      ContentCatalog.instance.reset();
    }
  });

  test('a reviewed translation always shows, a draft only with drafts on', () {
    const flags = {'en': true, 'fr': true, 'de': false};
    expect(pickLocale(flags, 'fr'), 'fr');
    expect(pickLocale(flags, 'fr', drafts: true), 'fr');
    expect(pickLocale(flags, 'de'), 'en');
    expect(pickLocale(flags, 'de', drafts: true), 'de');
    expect(pickLocale(flags, 'es', drafts: true), 'en', reason: 'none');
    expect(pickLocale(flags, 'en'), 'en');
  });

  test('the bundled snapshot carries every draft, flagged unreviewed', () {
    for (final item in snapshot.items) {
      expect(item.text['en']!.reviewed, isTrue);
      for (final locale in _translations) {
        expect(item.text[locale]?.reviewed, isFalse, reason: item.id);
        expect(item.textFor(locale).title, item.text['en']!.title);
        expect(
          item.textFor(locale, drafts: true).title,
          item.text[locale]!.title,
        );
      }
    }
    for (final course in snapshot.courses) {
      for (final locale in _translations) {
        expect(course.text[locale]?.reviewed, isFalse, reason: course.id);
        expect(course.textFor(locale).title, course.text['en']!.title);
      }
    }
  });

  test('a translation without the flag counts as reviewed', () {
    // Snapshots from before drafts were published had only reviewed ones.
    final s = _withItem('breathing:Box breathing', (i) {
      (i['text'] as Map)['fr'] = {'title': 'Respiration carrée', 'blurb': 'x'};
    });
    final box = s.items.firstWhere((i) => i.id == 'breathing:Box breathing');
    expect(box.textFor('fr').title, 'Respiration carrée');
  });

  test('with drafts on, content follows the app\'s language', () {
    debugDraftsOverride = true;
    LocaleSetting.instance.value = 'fr';
    expect(contentLocale, 'fr');
    final items = contentItemsFrom(snapshot);
    final box = items.firstWhere((i) => i.id == 'breathing:Box breathing');
    expect(box.title, 'Respiration carrée');
    expect(box.alsoMatches, contains('Box breathing'));
    expect(box.inEnglish, isFalse);
    expect(box.meta(), isNot(contains('EN')));

    // Ids are the content ids, whatever the title says.
    expect(
      [for (final i in items) i.id],
      [for (final i in snapshot.items) i.id],
    );
    final course = coursesFrom(snapshot, items).first;
    expect(course.title, snapshot.courses.first.text['fr']!.title);
    expect([
      for (final d in course.days) d.itemId,
    ], snapshot.courses.first.days);
  });

  test('without drafts, an unreviewed language falls back to English', () {
    debugDraftsOverride = false;
    LocaleSetting.instance.value = 'fr';
    // A release build doesn't offer French yet, so the app is in English.
    expect(contentLocale, 'en');
    final box = contentItemsFrom(
      snapshot,
    ).firstWhere((i) => i.id == 'breathing:Box breathing');
    expect(box.title, 'Box breathing');
    expect(box.alsoMatches, isEmpty);
    expect(box.inEnglish, isFalse);
  });

  test('English inside another language is marked EN', () {
    debugDraftsOverride = true;
    LocaleSetting.instance.value = 'de';
    final s = _withItem('breathing:Box breathing', (i) {
      (i['text'] as Map).remove('de');
    });
    final box = contentItemsFrom(
      s,
    ).firstWhere((i) => i.id == 'breathing:Box breathing');
    expect(box.title, 'Box breathing');
    expect(box.inEnglish, isTrue);
    expect(box.meta(), endsWith(' · EN'));
  });

  test('the catalogue rebuilds in a newly chosen language', () {
    debugDraftsOverride = true;
    ContentCatalog.instance.use(snapshot);
    String boxTitle() =>
        contentIndex.firstWhere((i) => i.id == 'breathing:Box breathing').title;
    expect(boxTitle(), 'Box breathing');
    LocaleSetting.instance.value = 'es';
    ContentCatalog.instance.relocalise();
    expect(boxTitle(), 'Respiración cuadrada');
    expect(courses.first.title, snapshot.courses.first.text['es']!.title);
  });

  testWidgets('a translated meditation runs without its English voice', (
    tester,
  ) async {
    debugDraftsOverride = true;
    // Null means every path counts as shipped with the app.
    bundledAssetsForTest = null;
    const id = 'meditation:Body scan';
    final withVoice = _withItem(id, (i) {
      (i['body'] as Map)['narration'] = 'assets/narration/body_scan.m4a';
    }).items.firstWhere((i) => i.id == id);
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));
    Meditation meditation() =>
        (screenFor(withVoice)!(context) as MeditationScreen).meditation;

    expect(meditation().narration, withVoice.body['narration']);
    LocaleSetting.instance.value = 'fr';
    expect(meditation().narration, isNull);
    expect(meditation().title, withVoice.text['fr']!.title);
    expect(meditation().id, withVoice.id);
  });

  test('background titles keep drafts only when drafts are on', () {
    debugDraftsOverride = false;
    final off = CatalogSnapshot.fromJson(_bundledJson())!;
    expect(off.backgrounds, isNotEmpty);
    for (final b in off.backgrounds) {
      expect(b.titles.keys, ['en']);
    }
    debugDraftsOverride = true;
    final on = CatalogSnapshot.fromJson(_bundledJson())!;
    expect(on.backgrounds.first.titles.keys, containsAll(_translations));
  });
}
