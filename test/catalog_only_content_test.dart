import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/journal/journal_hub_screen.dart';
import 'package:yournotalone/journal/journal_prompts.dart';
import 'package:yournotalone/journal/journal_repository.dart';
import 'package:yournotalone/media/media_files.dart';
import 'package:yournotalone/media/media_source.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/meditation/meditations_screen.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';
import 'package:yournotalone/sounds/sounds_screen.dart';

/// Content added only in `content/` (as the admin page will) has no Dart
/// counterpart. It must still show on the hubs, not just Home and search.

class _NoJournal extends JournalRepository {
  @override
  Future<int> countEntries() async => 0;
}

Map<String, dynamic> _bundledJson() =>
    jsonDecode(File(bundledCatalogAsset).readAsStringSync())
        as Map<String, dynamic>;

const _soundPath = 'Sounds/harbour_rain.wav';
final _sha = 'a' * 64;

Map<String, dynamic> _item(
  String id,
  String kind,
  Map<String, dynamic> body,
  Map<String, dynamic> en, {
  int? minutes,
  List<String> needs = const ['stressed'],
}) => {
  'id': id,
  'kind': kind,
  'order': 9999,
  'premium': false,
  'minutes': ?minutes,
  'icon': 'grain_rounded',
  'accent': 'blue',
  'tags': {'needs': needs, 'dayParts': <String>[]},
  'text': {'en': en},
  'body': body,
};

/// The bundled snapshot plus a sound, a meditation and two prompts that
/// exist nowhere in Dart.
CatalogSnapshot _withNewContent() {
  final json = _bundledJson();
  (json['items'] as List).addAll([
    _item(
      'sound-harbour-rain',
      'sound',
      {
        'type': 'sound',
        'category': 'sleep',
        'audio': _soundPath,
        'loop': true,
        'waveFreq': 3.0,
        'waveSpeed': 1,
        'waveHeight': 0.4,
        'pulse': false,
      },
      {
        'title': 'Harbour rain',
        'blurb': 'Rain on a quiet harbour.',
        'area': 'Sound · Sleep',
      },
      needs: ['sleep'],
    ),
    _item(
      'med-quiet-harbour',
      'meditation',
      {
        'type': 'meditation',
        'promptAt': [0, 0.5],
      },
      {
        'title': 'Quiet harbour',
        'blurb': 'Five minutes by the water.',
        'prompts': ['Settle in.', 'Let the tide go out.'],
      },
      minutes: 5,
    ),
    _item(
      'prompt-harbour-notes',
      'prompt',
      {'type': 'prompt', 'group': 'Looking back'},
      {
        'title': 'Harbour notes',
        'blurb': 'What came in with the tide this week.',
        'seed': 'This week, the tide brought ',
      },
      needs: ['reflect'],
    ),
    _item(
      'prompt-new-heading',
      'prompt',
      {'type': 'prompt', 'group': 'A heading from the future'},
      {
        'title': 'Unheaded prompt',
        'blurb': 'Its group has no heading in this build.',
        'seed': 'Today ',
      },
      needs: ['reflect'],
    ),
  ]);
  (json['media'] as Map<String, dynamic>)['sound-harbour-rain'] = {
    'audio': {
      'key': 'media/$_sha.m4a',
      'sha256': _sha,
      'bytes': 1000,
      'access': 'public',
    },
  };
  return CatalogSnapshot.fromJson(json)!;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
  });

  setUp(() {
    // The new sound's file isn't in the app; the rest stay playable.
    bundledAssetsForTest = {for (final s in soundsCatalog) s.asset, chimeAsset};
    ContentCatalog.instance.use(_withNewContent());
  });

  tearDown(() {
    bundledAssetsForTest = null;
    // Leave the catalogue as the run started.
    if (catalogSnapshotEnabled) {
      ContentCatalog.instance.use(CatalogSnapshot.fromJson(_bundledJson())!);
    } else {
      ContentCatalog.instance.reset();
    }
  });

  Widget wrap(Widget screen) =>
      MaterialApp(theme: buildAppTheme(), home: screen);

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      120,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a sound only in the catalogue is on the Sounds tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 4000);
    addTearDown(tester.view.reset);
    expect(soundLibrary.map((s) => s.id), contains('sound-harbour-rain'));

    await tester.pumpWidget(wrap(const SoundsScreen()));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Harbour rain');
    expect(find.text('Harbour rain'), findsOneWidget);
  });

  test('and plays from its published file', () async {
    final entry = ContentCatalog.instance.mediaAt(_soundPath)!;
    expect(entry.itemId, 'sound-harbour-rain');
    expect(entry.remote, isTrue);

    final temp = await Directory.systemTemp.createTemp('catalog_only');
    addTearDown(() => temp.delete(recursive: true));
    final origin = await MediaResolver(
      files: MediaFiles(support: () async => temp, cache: () async => temp),
    ).resolve(_soundPath);
    expect(origin, isA<RemoteAudio>());
    expect((origin! as RemoteAudio).entry.ref.key, 'media/$_sha.m4a');
  });

  testWidgets('a meditation only in the catalogue is on the meditations hub', (
    tester,
  ) async {
    expect(meditationLibrary.map((m) => m.id), contains('med-quiet-harbour'));

    await tester.pumpWidget(wrap(const MeditationsScreen()));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Quiet harbour');
    expect(find.text('Quiet harbour'), findsOneWidget);
  });

  testWidgets('a prompt only in the catalogue is in the journal hub', (
    tester,
  ) async {
    final prompts = {for (final p in journalPromptLibrary) p.title: p};
    expect(prompts['Harbour notes']!.group, 'Looking back');
    // A group this build has no heading for goes under the first one.
    expect(prompts['Unheaded prompt']!.group, promptGroups.first);

    await tester.pumpWidget(wrap(JournalHubScreen(journal: _NoJournal())));
    await tester.pumpAndSettle();
    await scrollTo(tester, 'Harbour notes');
    expect(find.text('Harbour notes'), findsOneWidget);
  });

  test('new items are in the index too, and log against their id', () {
    final ids = {for (final i in contentIndex) i.id};
    expect(
      ids,
      containsAll([
        'sound-harbour-rain',
        'med-quiet-harbour',
        'prompt-harbour-notes',
      ]),
    );
    expect(practiceSlug('sound-harbour-rain'), 'sound-harbour-rain');
    expect(practiceSlug('sound:Rainfall'), 'Rainfall');
    expect(practiceSlug('recovery:Urge surfing'), 'Urge surfing');
  });
}
