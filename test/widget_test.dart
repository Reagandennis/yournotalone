import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // Test-safe instance: no disk storage, no deep-link handling, and no
    // network use as long as nothing signs in.
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
  });

  Future<void> pumpPastSplash(WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3)); // pillar/text animation
    await tester.pump(const Duration(seconds: 1)); // hold before navigating
    await tester.pumpAndSettle(); // fade into the login screen
  }

  testWidgets('splash leads to the login screen', (tester) async {
    await pumpPastSplash(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
  });

  final authList = find
      .descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      )
      .first;

  /// Brings [text] into view in the current auth screen's list and returns
  /// its finder. [delta] is how far to scroll per step — negative to search
  /// back up the list.
  Future<Finder> scrollTo(
    WidgetTester tester,
    String text, {
    double delta = 80,
  }) async {
    final finder = find.text(text);
    await tester.scrollUntilVisible(finder, delta, scrollable: authList);
    // scrollUntilVisible stops once the target is built, which inside a
    // ListView's cache extent can still be past the edge of the viewport.
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return finder;
  }

  Future<void> scrollToAndTap(WidgetTester tester, String text) async {
    await tester.tap(await scrollTo(tester, text));
    await tester.pumpAndSettle();
  }

  testWidgets('login links to signup and reset password', (tester) async {
    await pumpPastSplash(tester);

    await scrollToAndTap(tester, 'Create an account');
    expect(find.text('Create your account'), findsOneWidget);

    await scrollToAndTap(tester, 'Log in'); // "Already have an account?"
    // Login kept the scroll offset it had when signup was pushed, so its
    // heading has to be scrolled back up to.
    expect(await scrollTo(tester, 'Welcome back', delta: -80), findsOneWidget);

    await scrollToAndTap(tester, 'Forgot password?');
    expect(find.text('Reset password'), findsOneWidget);
  });

  testWidgets('Google is offered on both login and signup', (tester) async {
    await pumpPastSplash(tester);

    expect(await scrollTo(tester, 'Continue with Google'), findsOneWidget);

    await scrollToAndTap(tester, 'Create an account');
    expect(await scrollTo(tester, 'Continue with Google'), findsOneWidget);
  });
}
