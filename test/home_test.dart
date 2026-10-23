import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/home_shell.dart';
import 'package:yournotalone/home/home_tab.dart';
import 'package:yournotalone/home/mood_face.dart';
import 'package:yournotalone/home/settings_tab.dart';

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

  testWidgets('home shell switches between the three tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
    );
    await tester.pumpAndSettle();

    // Home tab is up first: mood check-in, then quick access further down.
    expect(find.text('How are you feeling today?'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quick access'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(HomeTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Quick access'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('What do you need right now?'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Free plan'), findsOneWidget);

    final logoutFinder = find.text('Log out');
    await tester.scrollUntilVisible(
      logoutFinder,
      80,
      scrollable: find
          .descendant(
            of: find.byType(SettingsTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(logoutFinder, findsOneWidget);
  });

  testWidgets('mood check-in lights up the selected face', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
    );
    await tester.pumpAndSettle();

    // Only the faces in the check-in row: an Awful pick opens a sheet with
    // its own, and the week strip below repeats today's pick.
    MoodFace face(String label) => tester.widget<MoodFace>(
          find
              .descendant(
                of: find.byType(HomeTab),
                matching: find.byWidgetPredicate(
                  (w) => w is MoodFace && w.level.label == label,
                ),
              )
              .first,
        );
    // Nothing picked yet: every face is in full colour.
    expect(face('Great').dimmed, isFalse);
    expect(face('Awful').dimmed, isFalse);

    await tester.tap(find.text('Great'));
    await tester.pumpAndSettle();
    expect(face('Great').dimmed, isFalse);
    expect(face('Awful').dimmed, isTrue);

    // Picking a different mood moves the emphasis.
    await tester.tap(find.text('Awful'));
    await tester.pumpAndSettle();
    expect(face('Awful').dimmed, isFalse);
    expect(face('Great').dimmed, isTrue);
  });
}
