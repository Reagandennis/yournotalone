import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/explore_tab.dart';
import 'package:yournotalone/home/home_ui.dart';
import 'package:yournotalone/journal/journal_hub_screen.dart';
import 'package:yournotalone/journal/journal_prompts.dart';
import 'package:yournotalone/meditation/meditations_screen.dart';

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

  Widget wrap(Widget screen) => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: SafeArea(child: screen)),
      );

  /// Brings [finder] into the small test viewport before asserting on it.
  Future<Finder> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return finder;
  }

  testWidgets('category cards preview what is inside', (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    // Meditations previews the first three items of its list, then says
    // how many more are waiting (3 breathing + 5 meditations = 8).
    expect(find.text('Meditations & breathing'), findsOneWidget);
    expect(find.text('Box breathing'), findsOneWidget);
    expect(find.text('4-7-8 calm'), findsOneWidget);
    expect(find.text('Slow exhale'), findsOneWidget);
    expect(find.text('2 free · 18 Premium'), findsOneWidget);
    expect(find.text('+ 17 more inside'), findsOneWidget);
    // Locked items are badged right there in the preview.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('4-7-8 calm'),
          matching: find.byType(Row),
        ),
        matching: find.byType(PremiumChip),
      ),
      findsOneWidget,
    );

    // Sounds previews three of the five in the catalogue.
    expect(await scrollTo(tester, find.text('Deep focus')), findsOneWidget);
    expect(find.text('+ 10 more inside'), findsOneWidget);

    // Journal counts everything the hub lists, prompts included.
    expect(await scrollTo(tester, find.text('Journal & mood')), findsOneWidget);
    expect(find.text('3 free · 19 Premium'), findsOneWidget);
    expect(find.text('+ 19 more inside'), findsOneWidget);

    // Recovery is the last card, above the therapy banner.
    expect(await scrollTo(tester, find.text('Urge surfing')), findsOneWidget);
    expect(find.text('1 free · 6 Premium'), findsOneWidget);
    expect(find.text('+ 4 more inside'), findsOneWidget);
  });

  testWidgets('opening a card shows the full list to pick from',
      (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Meditations & breathing'));
    await tester.pumpAndSettle();

    expect(find.byType(MeditationsScreen), findsOneWidget);
    // Everything the card only teased is now listed.
    expect(
      await scrollTo(tester, find.text('Sleep wind-down')),
      findsOneWidget,
    );
    expect(
      await scrollTo(tester, find.text('Loving kindness')),
      findsOneWidget,
    );
  });

  testWidgets('added sessions are listed, badged and gated', (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Meditations & breathing'));
    await tester.pumpAndSettle();

    // One of the new breathing patterns, locked behind Premium.
    await scrollTo(tester, find.text('Panic reset'));
    await tester.tap(find.text('Panic reset'));
    await tester.pumpAndSettle();
    expect(find.text('This session is part of Premium'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // And one of the new meditations.
    await scrollTo(tester, find.text('Deep rest'));
    await tester.tap(find.text('Deep rest'));
    await tester.pumpAndSettle();
    expect(find.text('This session is part of Premium'), findsOneWidget);
  });

  testWidgets('journal card opens the hub with its prompts', (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    await tester.tap(await scrollTo(tester, find.text('Journal & mood')));
    await tester.pumpAndSettle();

    expect(find.byType(JournalHubScreen), findsOneWidget);
    expect(find.text('My journal'), findsOneWidget);
    expect(find.text('Free write'), findsOneWidget);
    expect(find.text('Gratitude'), findsOneWidget);

    // Prompts are grouped, so a long library stays pickable. Walk the
    // page top to bottom, checking each heading and one prompt under it.
    const underEachGroup = {
      'Everyday': 'Three lines',
      'Hard days': 'Worry dump',
      'Looking back': 'Letter to myself',
      'Recovery': 'Why I started',
      'Before sleep': 'Put the day down',
    };
    expect(underEachGroup.keys, promptGroups);
    for (final group in promptGroups) {
      expect(await scrollTo(tester, find.text(group)), findsOneWidget);
      expect(
        await scrollTo(tester, find.text(underEachGroup[group]!)),
        findsOneWidget,
      );
    }
  });

  testWidgets('mood history is gated, then opens', (tester) async {
    await tester.pumpWidget(wrap(const ExploreTab()));
    await tester.pumpAndSettle();

    await tester.tap(await scrollTo(tester, find.text('Journal & mood')));
    await tester.pumpAndSettle();

    await tester.tap(await scrollTo(tester, find.text('Mood history')));
    await tester.pumpAndSettle();
    expect(find.text('Mood history is part of Premium'), findsOneWidget);
  });
}
