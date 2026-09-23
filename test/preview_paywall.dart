// Renders the paywall with fake store packages and the real Poppins font
// to a PNG, for looking at it without a device. Not a test of anything —
// the name keeps it out of `flutter test`'s default run. Run with:
//   flutter test test/preview_paywall.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/onboarding/paywall_screen.dart';

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

  testWidgets('preview', (tester) async {
    final loader = FontLoader('Poppins');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
    }
    await loader.load();

    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(800, 3300);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: PaywallScreen(
        checkin: 'stressed',
        fromOnboarding: true,
        packages: fakePackages(),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('paywall_preview.png'),
    );
  });
}
