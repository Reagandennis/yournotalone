import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/reminders/reminders_screen.dart';
import 'package:yournotalone/reminders/reminders_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget screen) =>
      MaterialApp(theme: buildAppTheme(), home: screen);

  testWidgets('lists all four reminders with default times', (tester) async {
    await tester.pumpWidget(wrap(const RemindersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Morning check-in'), findsOneWidget);
    expect(find.text('Daily pledge'), findsOneWidget);
    expect(find.text('Evening pages'), findsOneWidget);
    expect(find.text('Wind-down'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(4));
    expect(find.text('9:00 AM'), findsOneWidget); // check-in default
  });

  testWidgets('toggling a reminder persists across screen reopenings',
      (tester) async {
    await tester.pumpWidget(wrap(const RemindersScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    Switch firstSwitch() => tester.widget<Switch>(find.byType(Switch).first);
    expect(firstSwitch().value, isTrue);

    // Rebuild the screen fresh — the preference should survive.
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pumpWidget(wrap(const RemindersScreen()));
    await tester.pumpAndSettle();
    expect(firstSwitch().value, isTrue);

    expect(
      await RemindersService.instance.isEnabled(ReminderKind.checkin),
      isTrue,
    );
  });

  testWidgets('changing the time updates the chip', (tester) async {
    await tester.pumpWidget(wrap(const RemindersScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('9:00 AM'));
    await tester.pumpAndSettle();
    // Confirm the picker with its initial value.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('9:00 AM'), findsOneWidget);
  });

  test('the next reminder keeps its wall-clock time across a clock change',
      () {
    tzdata.initializeTimeZones();
    final london = tz.getLocation('Europe/London');
    // Clocks go forward overnight into Sunday 29 March 2026.
    final saturdayEvening = tz.TZDateTime(london, 2026, 3, 28, 21);
    final next = RemindersService.nextInstanceAfter(
      saturdayEvening,
      const TimeOfDay(hour: 9, minute: 0),
    );
    expect((next.year, next.month, next.day, next.hour, next.minute),
        (2026, 3, 29, 9, 0));
    // And back again in October.
    final autumn = RemindersService.nextInstanceAfter(
      tz.TZDateTime(london, 2026, 10, 24, 22),
      const TimeOfDay(hour: 8, minute: 30),
    );
    expect((autumn.day, autumn.hour, autumn.minute), (25, 8, 30));
  });
}
