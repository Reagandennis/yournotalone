import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/auth/auth_ui.dart';
import 'package:yournotalone/auth/login_screen.dart';
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

  /// Scrolls [finder] into view. scrollUntilVisible only guarantees the
  /// widget has been *built*, so ensureVisible follows to bring it fully
  /// on-screen — without it, a widget near the bottom edge is untappable.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      80,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> scrollToAndTap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await scrollTo(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('splash leads to the login screen', (tester) async {
    await pumpPastSplash(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsWidgets);
  });

  testWidgets('login and signup both offer Google sign-in', (tester) async {
    await pumpPastSplash(tester);

    // The auth screens are lazy ListViews, so the button has to be scrolled
    // into view before it is built.
    await scrollTo(tester, find.byType(GoogleAuthButton));
    expect(find.byType(GoogleAuthButton), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    await scrollToAndTap(tester, 'Create an account');
    expect(find.text('Create your account'), findsOneWidget);

    await scrollTo(tester, find.byType(GoogleAuthButton));
    expect(find.byType(GoogleAuthButton), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('login links to signup and reset password', (tester) async {
    await pumpPastSplash(tester);

    await scrollToAndTap(tester, 'Create an account');
    expect(find.text('Create your account'), findsOneWidget);

    await scrollToAndTap(tester, 'Log in'); // "Already have an account?"
    // Assert on the route, not the title: the login ListView keeps its
    // scroll offset, so the heading may be scrolled out and unbuilt.
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Create your account'), findsNothing);

    await scrollToAndTap(tester, 'Forgot password?');
    expect(find.text('Reset password'), findsOneWidget);
  });
}
