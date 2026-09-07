import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/recovery/recovery_repository.dart';
import 'package:yournotalone/recovery/recovery_screen.dart';

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

  Widget wrap(Widget screen) =>
      MaterialApp(theme: buildAppTheme(), home: screen);

  Future<Finder> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return finder;
  }

  testWidgets('recovery hub shows SOS free and locks the rest for free users',
      (tester) async {
    // Tall enough for the upgrade sheet to fit — on the default 800x600
    // surface its buttons land off-screen and taps silently miss, which
    // made this test assert against a sheet that never closed.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const RecoveryScreen()));
    await tester.pumpAndSettle();

    // Urge surfing stays outside the paywall, at the top.
    expect(find.text('Craving right now?'), findsOneWidget);

    // Walk down the page: every tool below the SOS card is gated, and
    // tapping one sends a free user to the upgrade sheet.
    await tester.tap(await scrollTo(tester, find.text('HALT check')));
    await tester.pumpAndSettle();
    expect(
        find.text('Recovery tracking is part of Premium'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Recovery tracking is part of Premium'), findsNothing);

    for (final tool in [
      'Play the tape forward',
      'My commitments',
      'Milestones',
      'Trigger tracker',
      'Trigger insights',
    ]) {
      expect(await scrollTo(tester, find.text(tool)), findsOneWidget);
    }

    await tester.tap(await scrollTo(tester, find.text('Trigger insights')));
    await tester.pumpAndSettle();
    expect(
        find.text('Recovery tracking is part of Premium'), findsOneWidget);
  });

  testWidgets('urge surfing opens for everyone and runs to completion',
      (tester) async {
    await tester.pumpWidget(wrap(const RecoveryScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Craving right now?'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Urge surfing'), findsOneWidget);
    expect(
      find.text('You\'re here — that\'s the strongest move you could make.'),
      findsOneWidget,
    );

    await tester.pump(const Duration(minutes: 8));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Session complete'), findsOneWidget);
  });

  test('streak maths: day counts, milestones, and progress', () {
    final today = DateTime.now();
    final habit = RecoveryHabit(
      id: 'x',
      name: 'Alcohol',
      dayOne: today.subtract(const Duration(days: 9)),
      bestStreakDays: 0,
      pledgedToday: false,
    );
    expect(habit.daysIn, 10);
    expect(habit.nextMilestone, (14, '2 weeks'));
    // Between the 7-day and 14-day milestones: (10-7)/(14-7).
    expect(habit.milestoneProgress, closeTo(3 / 7, 0.001));

    final fresh = RecoveryHabit(
      id: 'y',
      name: 'Smoking',
      dayOne: today,
      bestStreakDays: 5,
      pledgedToday: true,
    );
    expect(fresh.daysIn, 1);
    expect(fresh.nextMilestone, (3, '3 days'));
  });
}
