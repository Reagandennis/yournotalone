import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/purchases_service.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/explore_tab.dart';
import 'package:yournotalone/stress/control_circle_screen.dart';
import 'package:yournotalone/stress/muscle_relaxation_screen.dart';
import 'package:yournotalone/stress/recharge_screen.dart';
import 'package:yournotalone/stress/sigh_screen.dart';
import 'package:yournotalone/stress/stress_catalog.dart';
import 'package:yournotalone/stress/stress_checkin_screen.dart';
import 'package:yournotalone/stress/stress_content.dart';
import 'package:yournotalone/stress/stress_screen.dart';
import 'package:yournotalone/toolkit/toolkit_links.dart';

Widget _wrap(Widget screen) => MaterialApp(theme: buildAppTheme(), home: screen);

Finder _button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

Future<Finder> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  return finder;
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

  test('the practices the programme links to still exist by name', () {
    expect(meditationTitled(stressMeditationTitle).title, stressMeditationTitle);
    expect(breathPatternTitled(stressBreathingTitle).title, stressBreathingTitle);
  });

  test('the check-in scores coping questions the other way round', () {
    expect(stressScore([0, 0, 4, 4, 0]), 0);
    expect(stressScore([4, 4, 0, 0, 4]), 20);
    expect(stressScore([2, 2, 2, 2, 2]), 10);
    expect(stressBand(3).$1, 'Low');
    expect(stressBand(10).$1, 'Moderate');
    expect(stressBand(17).$1, 'High');
  });

  testWidgets('Explore\'s stress card opens the programme with its tools',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const Scaffold(body: ExploreTab())));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Manage stress'));
    await tester.tap(find.text('Manage stress'));
    await tester.pumpAndSettle();

    expect(find.byType(StressScreen), findsOneWidget);
    for (final tool in stressTools) {
      expect(await _scrollTo(tester, find.text(tool.title)), findsOneWidget);
    }
    expect(await _scrollTo(tester, find.text(stressLessons.first.title)), findsOneWidget);
    expect(await _scrollTo(tester, find.text(stressResources.first.title)), findsOneWidget);
  });

  testWidgets('the sigh is the free taste; tense and release needs Premium',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const StressScreen()));
    await tester.pumpAndSettle();

    expect(find.text('1 free · 6 Premium'), findsOneWidget);
    await tester.tap(find.text('Physiological sigh'));
    await tester.pumpAndSettle();
    expect(find.byType(SighScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tense and release'));
    await tester.pumpAndSettle();
    expect(find.byType(MuscleRelaxationScreen), findsNothing);
    expect(find.text('This is part of Premium'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    PurchasesService.instance.isPro.value = true;
    addTearDown(() => PurchasesService.instance.isPro.value = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tense and release'));
    await tester.pumpAndSettle();
    expect(find.byType(MuscleRelaxationScreen), findsOneWidget);
  });

  testWidgets('a check-in is scored, explained and kept', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(StressCheckinScreen(clock: () => DateTime(2026, 9, 30))));
    await tester.pumpAndSettle();

    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    for (var i = 0; i < stressQuestions.length; i++) {
      await _scrollTo(tester, find.textContaining(stressQuestions[i].text));
      final card = find.ancestor(
          of: find.textContaining(stressQuestions[i].text), matching: find.byType(Material)).first;
      await tester.tap(find.descendant(of: card, matching: find.text('Often')));
      await tester.pump();
    }
    await tester.tap(_button('See my score'));
    await tester.pumpAndSettle();

    // Often on everything: 3+3+(4-3)+(4-3)+3.
    expect(find.text('11 out of 20 · Moderate'), findsOneWidget);
    expect((await loadStressCheckins()).single.score, 11);
  });

  testWidgets('stressors are sorted into circles with a next step', (tester) async {
    await tester.pumpWidget(_wrap(const ControlCircleScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'The rent');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Control'));
    await tester.pumpAndSettle();

    expect(find.text('Control · 1'), findsOneWidget);
    expect(find.text('Work one through'), findsOneWidget);
    expect((await loadStressors()).single.zone, Zone.control);
  });

  testWidgets('the sigh runs two breaths in and a long one out', (tester) async {
    await tester.pumpWidget(_wrap(const SighScreen(rounds: 2)));
    await tester.pumpAndSettle();

    await tester.tap(_button('Start'));
    await tester.pump();
    expect(find.text('Round 1 of 2'), findsOneWidget);
    expect(find.text('Breathe in'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('One more sip'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Long breath out'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Round 2 of 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('That\'s the round'), findsOneWidget);
    expect(find.text('Another round'), findsOneWidget);
  });

  testWidgets('tense and release moves through the groups on its own',
      (tester) async {
    await tester.pumpWidget(_wrap(const MuscleRelaxationScreen(tenseSeconds: 1, releaseSeconds: 1)));
    await tester.pumpAndSettle();

    await tester.tap(_button('Begin'));
    await tester.pump();
    expect(find.text('Hands'), findsOneWidget);
    expect(find.text('Tense'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Release'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Arms'), findsOneWidget);
    await tester.tap(_button('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('Begin'), findsOneWidget);
  });

  testWidgets('the recharge list keeps drains, refills and today\'s pick',
      (tester) async {
    // Tall enough that nothing needs scrolling: dragging over the text
    // fields would select text instead of moving the list.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(RechargeScreen(clock: () => DateTime(2026, 9, 30))));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Add a drain'), 'Late meetings');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ten minutes outside in daylight'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InputChip, 'Ten minutes outside in daylight'));
    await tester.pumpAndSettle();

    expect(find.text('Today: Ten minutes outside in daylight'), findsOneWidget);
    final list = await RechargeList.load();
    expect(list.drains, ['Late meetings']);
    expect(list.pickFor('2026-09-30'), 'Ten minutes outside in daylight');
  });
}
