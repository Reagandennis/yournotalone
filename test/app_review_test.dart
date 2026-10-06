// Things App Review checks for that are easy to break without noticing.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/legal/legal_screen.dart';
import 'package:yournotalone/onboarding/paywall_screen.dart';
import 'package:yournotalone/support/faq_screen.dart';

import 'fake_packages.dart';

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

  void tallScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2600);
    addTearDown(tester.view.reset);
  }

  group('paywall (guideline 3.1.2)', () {
    testWidgets('shows price, period, restore, terms and privacy policy',
        (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(wrap(PaywallScreen(
        checkin: 'steady',
        fromOnboarding: true,
        packages: fakePackages(),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('cancel anytime'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    for (final (label, title) in [
      ('Terms of Use', 'Terms of Service'),
      ('Privacy Policy', 'Privacy Policy'),
    ]) {
      testWidgets('"$label" opens the full document', (tester) async {
        tallScreen(tester);
        await tester.pumpWidget(wrap(PaywallScreen(
          checkin: 'steady',
          fromOnboarding: true,
          packages: fakePackages(),
        )));
        await tester.pumpAndSettle();

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        final legal = find.byType(LegalScreen);
        expect(legal, findsOneWidget);
        expect(tester.widget<LegalScreen>(legal).doc.title, title);
      });
    }
  });

  group('FAQ names only this device\'s store (guideline 2.3.10)', () {
    Future<String> faqText(WidgetTester tester, TargetPlatform platform) async {
      debugDefaultTargetPlatformOverride = platform;
      tallScreen(tester);
      await tester.pumpWidget(wrap(const FaqScreen()));
      await tester.pumpAndSettle();
      // Open every answer so their text is in the tree.
      for (final q in [
        'How do I cancel my subscription?',
        'I\'m a subscriber, but the app says I\'m on the Free plan.',
        'Can I get a refund?',
      ]) {
        await tester.ensureVisible(find.text(q));
        await tester.tap(find.text(q));
        await tester.pumpAndSettle();
      }
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .join('\n');
      debugDefaultTargetPlatformOverride = null;
      return text;
    }

    testWidgets('iPhone: App Store only', (tester) async {
      final text = await faqText(tester, TargetPlatform.iOS);
      expect(text, contains('App Store subscription settings'));
      expect(text, isNot(contains('Google')));
    });

    testWidgets('Android: Google Play only', (tester) async {
      final text = await faqText(tester, TargetPlatform.android);
      expect(text, contains('Google Play subscription settings'));
      expect(text, isNot(contains('App Store')));
      expect(text, isNot(contains('Apple')));
    });
  });
}
