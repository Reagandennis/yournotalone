import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/purchases_service.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/explore_tab.dart';
import 'package:yournotalone/journal/journal_repository.dart';
import 'package:yournotalone/sleep/awake_screen.dart';
import 'package:yournotalone/sleep/sleep_catalog.dart';
import 'package:yournotalone/sleep/sleep_content.dart';
import 'package:yournotalone/sleep/sleep_diary_screen.dart';
import 'package:yournotalone/sleep/sleep_habits_screen.dart';
import 'package:yournotalone/sleep/sleep_screen.dart';
import 'package:yournotalone/sleep/tomorrow_list_screen.dart';
import 'package:yournotalone/sleep/wind_down_screen.dart';
import 'package:yournotalone/toolkit/toolkit_links.dart';

class _FakeJournal extends JournalRepository {
  final saved = <(String?, String)>[];

  @override
  Future<int> countEntries() async => 0;

  @override
  Future<void> create({String? title, required String content}) async =>
      saved.add((title, content));
}

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

final _morning = DateTime(2026, 9, 30, 8);

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
    expect(meditationTitled(sleepMeditationTitle).title, sleepMeditationTitle);
    expect(meditationTitled('Deep rest').title, 'Deep rest');
    expect(breathPatternTitled(sleepBreathingTitle).title, sleepBreathingTitle);
    expect(breathPatternTitled('Box breathing').premium, isFalse);
  });

  group('sleep arithmetic', () {
    test('a night across midnight adds up', () {
      const n = SleepNight(
        date: '2026-09-30',
        bedMinutes: 23 * 60 + 30,
        wakeMinutes: 6 * 60 + 30,
        latency: 30,
        awake: 30,
        quality: 3,
      );
      expect(n.timeInBed, 420);
      expect(n.totalSleep, 360);
      expect(n.efficiency, closeTo(0.857, 0.001));
    });

    test('a week of poor nights earns a tighter window', () {
      final nights = [
        for (var i = 0; i < 7; i++)
          SleepNight(
            date: '2026-09-2$i',
            bedMinutes: 22 * 60,
            wakeMinutes: 7 * 60,
            latency: 60,
            awake: 90,
            quality: 2,
          ),
      ];
      final s = SleepSummary(nights);
      expect(s.averageEfficiency, lessThan(0.85));
      expect(s.verdict, contains('Tighten the window'));
      // 6h30 asleep + 30 min = 7h, ending at the usual 07:00: bed at midnight.
      expect(s.window, (0, 7 * 60));
    });

    test('fewer than five nights suggests no window yet', () {
      final s = SleepSummary([
        const SleepNight(date: 'a', bedMinutes: 1380, wakeMinutes: 420, latency: 10, awake: 0, quality: 4),
      ]);
      expect(s.window, isNull);
      expect(s.verdict, contains('Five nights in'));
    });
  });

  testWidgets('Explore\'s sleep card opens the programme with its tools',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const Scaffold(body: ExploreTab())));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('Sleep better'));
    await tester.tap(find.text('Sleep better'));
    await tester.pumpAndSettle();

    expect(find.byType(SleepScreen), findsOneWidget);
    for (final tool in sleepTools) {
      expect(await _scrollTo(tester, find.text(tool.title)), findsOneWidget);
    }
    expect(await _scrollTo(tester, find.text(sleepLessons.first.title)), findsOneWidget);
    expect(await _scrollTo(tester, find.text(sleepResources.first.title)), findsOneWidget);
  });

  testWidgets('the wind-down is the free taste; the diary needs Premium',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const SleepScreen()));
    await tester.pumpAndSettle();

    expect(find.text('1 free · 6 Premium'), findsOneWidget);
    await tester.tap(find.text('Wind-down plan'));
    await tester.pumpAndSettle();
    expect(find.byType(WindDownScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sleep diary'));
    await tester.pumpAndSettle();
    expect(find.byType(SleepDiaryScreen), findsNothing);
    expect(find.text('This is part of Premium'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // Premium opens it.
    PurchasesService.instance.isPro.value = true;
    addTearDown(() => PurchasesService.instance.isPro.value = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sleep diary'));
    await tester.pumpAndSettle();
    expect(find.byType(SleepDiaryScreen), findsOneWidget);
  });

  testWidgets('logging a night shows its efficiency and keeps it', (tester) async {
    await tester.pumpWidget(_wrap(SleepDiaryScreen(clock: () => _morning)));
    await tester.pumpAndSettle();
    expect(find.text('No nights yet. Log this morning\'s and the picture starts to form within a week.'), findsOneWidget);

    await tester.tap(find.text('Log last night'));
    await tester.pumpAndSettle();
    // Defaults: 23:00 to 07:00, 15 min to drop off, 10 min awake.
    await tester.tap(find.text('Good'));
    await tester.pump();
    await tester.tap(_button('Save night'));
    await tester.pumpAndSettle();

    expect(find.textContaining('7h 35m asleep, 95% efficient'), findsOneWidget);
    expect(find.text('95%'), findsWidgets);
    expect(find.text('Edit this morning\'s entry'), findsOneWidget);
    final kept = await loadSleepNights();
    expect(kept.single.quality, 4);
    expect(kept.single.date, '2026-09-30');
  });

  testWidgets('the wind-down counts back from bedtime and remembers ticks',
      (tester) async {
    await tester.pumpWidget(_wrap(WindDownScreen(clock: () => _morning)));
    await tester.pumpAndSettle();

    expect(find.text('Lights out at 10:30 PM'), findsOneWidget);
    expect(find.text('9:30 PM · 60 min before'), findsOneWidget);
    await tester.tap(find.text('Screens down, lights low'));
    await tester.pumpAndSettle();

    final plan = await WindDownPlan.load(_morning);
    expect(plan.done, {'screens'});
    expect(plan.at(5).format(tester.element(find.byType(WindDownScreen))), '10:25 PM');
  });

  testWidgets('putting the day down can go to the journal', (tester) async {
    final journal = _FakeJournal();
    await tester.pumpWidget(_wrap(TomorrowListScreen(journal: journal, clock: () => _morning)));
    await tester.pumpAndSettle();

    expect(tester.widget<TextButton>(_button('Save to journal')).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Thing 1'), 'Call the bank');
    await tester.pump();
    await _scrollTo(tester, find.widgetWithText(TextField, 'A worry that can wait until daylight'));
    await tester.enterText(
        find.widgetWithText(TextField, 'A worry that can wait until daylight'), 'The email');
    await tester.pump();
    await tester.tap(_button('Save to journal'));
    await tester.pumpAndSettle();

    expect(journal.saved.single.$1, 'Put the day down');
    expect(journal.saved.single.$2, contains('1. Call the bank'));
    expect(journal.saved.single.$2, contains('Letting go tonight: The email'));
  });

  testWidgets('awake at 3am walks through the 20-minute rule', (tester) async {
    await tester.pumpWidget(_wrap(const AwakeScreen(breakLength: Duration(seconds: 3))));
    await tester.pumpAndSettle();

    await tester.tap(_button('Yes — I\'ve been awake a while'));
    await tester.pumpAndSettle();
    expect(find.text('Get up. Low light, something dull.'), findsOneWidget);
    await tester.tap(_button('Start a 15-minute break'));
    await tester.pump();
    expect(find.text('00:03'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Back to bed when sleepy — not when the clock says'), findsOneWidget);
  });

  testWidgets('the habits check turns each yes into a fix', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const SleepHabitsScreen()));
    await tester.pumpAndSettle();

    for (var i = 0; i < sleepHabits.length; i++) {
      final label = i < 2 ? 'Yes' : 'No';
      await _scrollTo(tester, find.text(sleepHabits[i].question));
      final pill = find.descendant(
        of: find.ancestor(
            of: find.text(sleepHabits[i].question), matching: find.byType(Material)).first,
        matching: find.text(label),
      );
      await tester.tap(pill);
      await tester.pump();
    }
    await tester.tap(_button('See what to change'));
    await tester.pumpAndSettle();

    expect(find.text('2 of 10 to work on'), findsOneWidget);
    expect(find.textContaining('A fixed wake time'), findsOneWidget);
    expect(find.textContaining('half-life'), findsOneWidget);
  });
}
