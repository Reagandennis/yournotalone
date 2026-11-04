import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/sleep/sleep_catalog.dart';
import 'package:yournotalone/sleep/sleep_content.dart';
import 'package:yournotalone/toolkit/guided_exercise.dart';
import 'package:yournotalone/toolkit/toolkit_art.dart';

Map<String, dynamic> _bundledJson() =>
    jsonDecode(File(bundledCatalogAsset).readAsStringSync())
        as Map<String, dynamic>;

/// A guided item as the content admin writes it.
Map<String, dynamic> _guided(
  String id,
  String kind,
  String accent, {
  int titles = 2,
}) => {
  'id': id,
  'kind': kind,
  'order': 9000,
  'premium': false,
  'minutes': 4,
  'icon': 'spa_rounded',
  'accent': accent,
  'tags': {
    'needs': ['sleep'],
    'dayParts': <String>[],
  },
  'text': {
    'en': {
      'title': 'Settle for sleep',
      'blurb': 'Two steps to wind down.',
      'stepTitles': ['Breathe', 'Name three things'].take(titles).toList(),
      'steps': [
        'Slow your breathing for a minute.',
        'Write three good things from today.',
      ],
    },
  },
  'body': {
    'type': 'guided',
    'art': 'moon',
    'steps': [
      {'timer': 60},
      {'input': 'list', 'count': 3},
    ],
  },
};

CatalogSnapshot _withGuided(List<Map<String, dynamic>> extra) {
  final json = _bundledJson();
  (json['items'] as List).addAll(extra);
  return CatalogSnapshot.fromJson(json)!;
}

void main() {
  tearDown(() {
    if (catalogSnapshotEnabled) {
      ContentCatalog.instance.use(CatalogSnapshot.fromJson(_bundledJson())!);
    } else {
      ContentCatalog.instance.reset();
    }
  });

  test('a guided item becomes an exercise with its steps', () {
    final snapshot = _withGuided([
      _guided('tool-settle-for-sleep', 'tool', 'sleep'),
    ]);
    final item = snapshot.items.last;
    final model = modelFor(item) as GuidedExercise;
    expect(model.title, 'Settle for sleep');
    expect(model.art, ToolkitArtKind.moon);
    expect(
      [for (final s in model.steps) s.title],
      ['Breathe', 'Name three things'],
    );
    expect(model.steps.first.timerSeconds, 60);
    expect(model.steps.last.input, GuidedInput.list);
    expect(model.steps.last.count, 3);
    expect(screenFor(item), isNotNull);
  });

  test('guided tools join their toolkit, recovery ones the Recovery list', () {
    ContentCatalog.instance.use(
      _withGuided([
        _guided('tool-settle-for-sleep', 'tool', 'sleep'),
        _guided('recovery-ride-it-out', 'recovery', 'red'),
      ]),
    );
    final tools = toolkitTools(sleepAccent, sleepTools, ToolkitArtKind.moon);
    expect(tools, hasLength(sleepTools.length + 1));
    expect(tools.last.title, 'Settle for sleep');
    expect(
      toolkitTools(cbtAccentForTest, const [], ToolkitArtKind.learn),
      isEmpty,
    );
    expect(
      [for (final g in ContentCatalog.instance.guidedRecovery) g.title],
      ['Settle for sleep'],
    );
    expect(
      contentItemsFrom(
        _withGuided([_guided('recovery-ride-it-out', 'recovery', 'red')]),
      ).map((i) => i.id),
      contains('recovery-ride-it-out'),
    );
  });

  test('leaves out a guided item whose text has the wrong number of steps', () {
    final snapshot = _withGuided([
      _guided('tool-settle-for-sleep', 'tool', 'sleep', titles: 1),
    ]);
    expect(modelFor(snapshot.items.last), isNull);
    expect(
      contentItemsFrom(snapshot).map((i) => i.id),
      isNot(contains('tool-settle-for-sleep')),
    );
  });

  testWidgets('steps through, with a timer and a list, to the end', (
    tester,
  ) async {
    const exercise = GuidedExercise(
      id: 'tool-settle-for-sleep',
      title: 'Settle for sleep',
      blurb: 'Two steps to wind down.',
      minutes: 4,
      icon: Icons.spa_rounded,
      accent: sleepAccent,
      steps: [
        GuidedStep(
          title: 'Breathe',
          text: 'Slow your breathing.',
          timerSeconds: 60,
        ),
        GuidedStep(
          title: 'Name three things',
          text: 'Good things from today.',
          input: GuidedInput.list,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const GuidedExerciseScreen(exercise: exercise),
      ),
    );
    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('Start timer'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).first, 'A walk');

    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(find.text('Nicely done'), findsOneWidget);
    // Something was written, so it can go in the journal.
    expect(find.text('Save to journal'), findsOneWidget);

    await tester.tap(find.text('Go again'));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 2'), findsOneWidget);
  });
}

const cbtAccentForTest = Color(0xFF123456);
