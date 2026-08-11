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

  testWidgets('recovery hub shows SOS free and locks tracking for free users',
      (tester) async {
    await tester.pumpWidget(wrap(const RecoveryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Craving right now?'), findsOneWidget);
    expect(find.text('My commitments'), findsOneWidget);
    expect(find.text('Trigger tracker'), findsOneWidget);
    // Free users see the two locked cards with Premium chips.
    expect(find.text('Premium'), findsNWidgets(2));

    await tester.tap(find.text(
        'Count every day, pledge each morning, and celebrate milestones.'));
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
