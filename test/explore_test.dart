import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/content_widgets.dart';
import 'package:yournotalone/discover/usage_store.dart';
import 'package:yournotalone/home/explore_tab.dart';
import 'package:yournotalone/journal/journal_hub_screen.dart';
import 'package:yournotalone/journal/journal_prompts.dart';
import 'package:yournotalone/meditation/breathing_screen.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';

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

  Widget wrap(Widget screen) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: SafeArea(child: screen)),
      );

  /// Brings [finder] into the small test viewport before asserting on it.
  Future<Finder> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return finder;
  }

  testWidgets('a need chip opens everything tagged for it', (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    expect(find.text('What do you need right now?'), findsOneWidget);
    await tester.tap(find.text(Need.sleep.label));
    await tester.pumpAndSettle();

    expect(find.byType(ContentListScreen), findsOneWidget);
    final sleep = [
      for (final item in contentIndex)
        if (item.needs.contains(Need.sleep)) item,
    ];
    expect(find.text(countLine(sleep)), findsOneWidget);
    // Free items lead, so the first thing a free user sees opens.
    expect(find.text('Wind-down plan'), findsOneWidget);
  });

  testWidgets('length filters narrow a list', (tester) async {
    await tester.pumpWidget(wrap(
      ContentListScreen.forNeed(Need.sleep),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text(LengthFilter.long.label));
    await tester.pumpAndSettle();
    // Deep rest is 15 minutes; the 3-minute habits check is gone.
    expect(find.text('Deep rest'), findsOneWidget);
    expect(find.text('Sleep habits check'), findsNothing);
  });

  testWidgets('collections count from the index and open their list',
      (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    final breathing = [
      for (final item in contentIndex)
        if (item.kind == ContentKind.breathing) item,
    ];
    expect(
      await scrollTo(
        tester,
        find.text(
          '${breathing.length} rhythms · ${countLine(breathing)}',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Breathing exercises'));
    await tester.pumpAndSettle();
    expect(find.byType(ContentListScreen), findsOneWidget);
    expect(find.text(breathPatterns.first.title), findsOneWidget);

    // Items open directly; a locked one shows the upgrade sheet.
    await tester.tap(find.text('4-7-8 calm'));
    await tester.pumpAndSettle();
    expect(find.text('This is part of Premium'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Box breathing'));
    // Not pumpAndSettle: the session screen animates its backdrop forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BreathingScreen), findsOneWidget);
  });

  testWidgets('journal pillar opens the hub with its prompts',
      (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    await tester.tap(await scrollTo(tester, find.text('Journal & mood')));
    await tester.pumpAndSettle();

    expect(find.byType(JournalHubScreen), findsOneWidget);
    expect(find.text('Free write'), findsOneWidget);
    expect(promptGroups, isNotEmpty);
  });

  testWidgets('search opens the item itself and remembers the query',
      (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    // Before typing: a way in by need.
    expect(find.text('Try searching for'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'box');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Box breathing'));
    // Not pumpAndSettle: the session screen animates its backdrop forever.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(BreathingScreen), findsOneWidget);

    expect(await UsageStore.instance.recentSearches(), ['box']);
  });

  testWidgets('search finds things by need, too', (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'panick');
    await tester.pumpAndSettle();
    expect(find.text('Panic reset'), findsOneWidget);
    expect(find.text('Grounding: 5-4-3-2-1'), findsOneWidget);
  });
}
