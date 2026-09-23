import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/pricing_copy.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/onboarding/checkin_screen.dart';
import 'package:yournotalone/onboarding/welcome_screen.dart';

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

  Future<Finder> scrollTo(WidgetTester tester, String text) async {
    final finder = find.text(text);
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
    return finder;
  }

  Future<void> scrollToAndTap(WidgetTester tester, String text) async {
    await tester.tap(await scrollTo(tester, text));
    await tester.pump();
  }

  testWidgets('welcome screen greets and explains the name', (tester) async {
    await tester.pumpWidget(wrap(const WelcomeScreen()));
    await tester.pump(const Duration(seconds: 3)); // reveal animation

    // No signed-in user in tests, so the fallback greeting shows.
    expect(find.text('Welcome, friend'), findsOneWidget);
    expect(find.text('Δεν είσαι μόνος'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Here to hold you up'), findsOneWidget);
  });

  testWidgets('check-in routes struggling users to the therapy offer',
      (tester) async {
    await tester.pumpWidget(wrap(const CheckinScreen()));
    await tester.pumpAndSettle();

    await scrollToAndTap(tester, 'In a dark place');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('You don\'t have to do this alone'), findsOneWidget);
    expect(
      await scrollTo(tester, 'Your first session is on us'),
      findsOneWidget,
    );
  });

  testWidgets('check-in routes steady users to the paywall', (tester) async {
    await tester.pumpWidget(wrap(const CheckinScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Doing okay'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Keep the good days coming'), findsOneWidget);
    expect(await scrollTo(tester, introOfferSentence), findsOneWidget);
  });
}
