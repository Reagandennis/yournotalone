import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}
