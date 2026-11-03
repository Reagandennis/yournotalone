import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/content_widgets.dart';
import 'package:yournotalone/discover/recommendations.dart';
import 'package:yournotalone/home/home_tab.dart';

/// Items the Worker suggests, with a reason code each.
const _picks = [
  {
    'id': 'tool:Grounding: 5-4-3-2-1',
    'reason': "Because you're working on anxiety",
    'reasonKey': 'goal',
    'reasonArgs': {'need': 'anxious'},
  },
  {
    'id': 'sound:Rainfall',
    'reason': 'For tonight',
    'reasonKey': 'dayPart',
    'reasonArgs': {'part': 'night'},
  },
  {
    'id': 'breathing:Box breathing',
    'reason': 'Because you felt better after Rainfall',
    'reasonKey': 'feltBetter',
    'reasonArgs': {'title': 'sound:Rainfall'},
  },
];

RecommendationsClient _worker() => RecommendationsClient.forTest(
  client: MockClient(
    (_) async => http.Response(
      jsonEncode({'items': _picks, 'rules': 'v1'}),
      200,
      headers: {'content-type': 'application/json'},
    ),
  ),
  baseUrl: 'https://api.test',
  token: () async => 'jwt',
);

Finder _strip() => find.byWidgetPredicate(
  (w) => w is ContentStrip && w.source.startsWith('home:'),
);

Future<void> _pumpHome(
  WidgetTester tester,
  RecommendationsClient? client,
) async {
  // Tall enough that the list builds the strip, well down the page.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 4000);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: HomeTab(
          recommendations: client,
          therapyRequests: () async => const [],
        ),
      ),
    ),
  );
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the Worker\'s reasons show under its suggestions, in the '
      'app\'s words', (tester) async {
    await _pumpHome(tester, _worker());
    await tester.pumpAndSettle();

    final strip = tester.widget<ContentStrip>(_strip());
    final ids = strip.items.map((i) => i.id).toList();
    // Whatever the daily pick takes out, the rest are the Worker's.
    expect(ids, everyElement(isIn(_picks.map((p) => p['id']))));
    if (ids.contains('tool:Grounding: 5-4-3-2-1')) {
      expect(
        strip.reasons['tool:Grounding: 5-4-3-2-1'],
        "Because you're working on anxiety",
      );
    }
    if (ids.contains('breathing:Box breathing')) {
      expect(
        strip.reasons['breathing:Box breathing'],
        'Because you felt better after Rainfall',
      );
    }
    expect(strip.reasons, isNotEmpty);
    for (final reason in strip.reasons.values) {
      expect(find.text(reason), findsOneWidget);
    }
    // "For tonight" would only repeat the heading.
    expect(strip.reasons.containsKey('sound:Rainfall'), isFalse);
  });

  testWidgets('the on-device order has no reasons', (tester) async {
    // A client with no Worker URL: Home orders the strip itself.
    await _pumpHome(
      tester,
      RecommendationsClient.forTest(
        client: MockClient((_) async => http.Response('', 500)),
        baseUrl: '',
        token: () async => 'jwt',
      ),
    );
    await tester.pumpAndSettle();

    final strip = tester.widget<ContentStrip>(_strip());
    expect(strip.items, isNotEmpty);
    expect(strip.reasons, isEmpty);
  });

  testWidgets('a card with a reason fits a narrow phone at large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);
    final items = contentIndex.take(3).toList();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: ListView(
              children: [
                ContentStrip(
                  items: items,
                  source: 'test',
                  reasons: {
                    for (final i in items)
                      i.id:
                          'Because you felt better after Progressive muscle '
                          'relaxation before bed',
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Because you felt better after Progressive muscle relaxation '
        'before bed',
      ),
      findsWidgets,
    );
  });
}
