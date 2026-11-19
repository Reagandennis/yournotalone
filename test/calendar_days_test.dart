import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/calendar_days.dart';
import 'package:yournotalone/recovery/milestones_screen.dart';
import 'package:yournotalone/recovery/recovery_repository.dart';

// The dates below are the 2026 changes in the EU: clocks go forward on
// 29 March and back on 25 October. Where the machine's zone has no daylight
// saving the local cases pass either way; the hand-built gaps check the
// same arithmetic everywhere. `TZ=Europe/Athens flutter test` runs them in
// the users' own zone.

class _Habits extends RecoveryRepository {
  _Habits(this.habits);

  final List<RecoveryHabit> habits;

  @override
  Future<List<RecoveryHabit>> fetchHabits() async => habits;
}

RecoveryHabit _habit(DateTime dayOne) => RecoveryHabit(
  id: 'h',
  name: 'Alcohol',
  dayOne: dayOne,
  bestStreakDays: 0,
  pledgedToday: false,
);

void main() {
  group('calendarDaysBetween', () {
    test('counts dates, not 24-hour blocks', () {
      expect(
        calendarDaysBetween(
          DateTime(2026, 11, 19, 0, 5),
          DateTime(2026, 11, 19, 23, 55),
        ),
        0,
      );
      expect(
        calendarDaysBetween(
          DateTime(2026, 11, 18, 23, 55),
          DateTime(2026, 11, 19, 0, 5),
        ),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 11, 19), DateTime(2026, 11, 12)),
        -7,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 12, 31), DateTime(2027, 1, 1)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2028, 2, 28), DateTime(2028, 3, 1)),
        2,
      );
    });

    test('the 23-hour day the clocks go forward still counts as one', () {
      expect(
        calendarDaysBetween(DateTime(2026, 3, 29), DateTime(2026, 3, 30)),
        1,
      );
      expect(
        calendarDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 4, 1)),
        31,
      );
      // Midnight to midnight across that night is 23 hours, which
      // Duration.inDays rounds down to nothing.
      final sunday = DateTime.utc(2026, 3, 29, 1);
      final monday = sunday.add(const Duration(hours: 23));
      expect(monday.difference(sunday).inDays, 0);
      expect(calendarDaysBetween(sunday, monday), 1);
    });

    test('the 25-hour day the clocks go back counts as one too', () {
      expect(
        calendarDaysBetween(DateTime(2026, 10, 25), DateTime(2026, 10, 26)),
        1,
      );
      final sunday = DateTime.utc(2026, 10, 25);
      final late = sunday.add(const Duration(hours: 24, minutes: 30));
      expect(calendarDaysBetween(sunday, late), 1);
    });
  });

  group('addCalendarDays', () {
    test(
      'lands on the next date at midnight, across the clocks going back',
      () {
        // Local midnight on 25 October plus 24 hours is 23:00 on the 25th
        // where the clocks go back that night.
        final next = addCalendarDays(DateTime(2026, 10, 25), 1);
        expect((next.year, next.month, next.day), (2026, 10, 26));
        expect((next.hour, next.minute), (0, 0));

        final week = addCalendarDays(DateTime(2026, 3, 26), 7);
        expect((week.month, week.day, week.hour), (4, 2, 0));
      },
    );

    test('goes back, across months and years, and keeps UTC as UTC', () {
      final back = addCalendarDays(DateTime(2026, 3, 1, 15, 30), -1);
      expect((back.month, back.day, back.hour), (2, 28, 0));
      final newYear = addCalendarDays(DateTime(2026, 12, 31), 1);
      expect((newYear.year, newYear.month, newYear.day), (2027, 1, 1));
      final utc = addCalendarDays(DateTime.utc(2026, 10, 25, 22), 2);
      expect(utc.isUtc, isTrue);
      expect(utc, DateTime.utc(2026, 10, 27));
    });
  });

  group('days sober', () {
    test('the night the clocks go forward is still a day', () {
      withClock(Clock.fixed(DateTime(2026, 3, 30, 0, 30)), () {
        expect(_habit(DateTime(2026, 3, 29)).daysIn, 2);
        expect(_habit(DateTime(2026, 3, 1)).daysIn, 30);
      });
    });

    test('day one is day 1 at any hour, and a future start is too', () {
      withClock(Clock.fixed(DateTime(2026, 11, 19, 23, 59)), () {
        expect(_habit(DateTime(2026, 11, 19)).daysIn, 1);
        expect(_habit(DateTime(2026, 11, 20)).daysIn, 1);
        expect(_habit(DateTime(2026, 11, 12)).daysIn, 8);
      });
    });
  });

  group('milestones', () {
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

    testWidgets('are reached on the right date after the clocks go back', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 2400);
      addTearDown(tester.view.reset);
      await withClock(Clock.fixed(DateTime(2026, 11, 19, 9)), () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: MilestonesScreen(
              repository: _Habits([_habit(DateTime(2026, 10, 24))]),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      expect(find.text('Day 27'), findsOneWidget);
      expect(find.text('Reached 24 Oct'), findsOneWidget);
      // Day 3 is the 26th, two calendar days on, with the 25-hour Sunday
      // in between.
      expect(find.text('Reached 26 Oct'), findsOneWidget);
      expect(find.text('Reached 30 Oct'), findsOneWidget);
      expect(find.text('Reached 6 Nov'), findsOneWidget);
    });
  });
}
