import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/support/crisis_resources.dart';
import 'package:yournotalone/support/crisis_screen.dart';

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

  test('every listed line can actually be reached', () {
    expect(crisisRegions, isNotEmpty);
    for (final region in crisisRegions) {
      expect(region.emergency, isNotEmpty, reason: region.label);
      expect(region.lines, isNotEmpty, reason: region.label);
      for (final line in region.lines) {
        // A line with no phone, no text and no link is decoration.
        expect(
          line.phone != null || line.sms != null || line.url != null,
          isTrue,
          reason: '${region.label} · ${line.name} has no way to reach it',
        );
        if (line.phone != null) {
          expect(dialable(line.phone!), matches(RegExp(r'^\+?\d{3,}$')),
              reason: '${line.name}: ${line.phone} is not dialable');
        }
      }
    }
  });

  test('an unknown country still gets somewhere to go', () {
    // The device locale in tests is en-US, but the fallback is what matters:
    // no region should ever leave a user with an empty list.
    expect(defaultCrisisRegion().lines, isNotEmpty);
    expect(internationalRegion.lines.any((l) => l.url != null), isTrue);
  });

  testWidgets('the screen leads with help, not with an upsell',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const CrisisScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Help right now'), findsOneWidget);

    // The emergency call sits above every other action on the page.
    final emergency = tester
        .getTopLeft(find.text('Call ${defaultCrisisRegion().emergency}'))
        .dy;
    final booking = tester.getTopLeft(find.text('Book a session')).dy;
    expect(emergency, lessThan(booking));

    // Real, tappable resources — not a paragraph telling you to look one up.
    expect(find.byType(OutlinedButton), findsWidgets);
  });

  testWidgets('you can switch country when the guess is wrong',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const CrisisScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kenya').last);
    await tester.pumpAndSettle();

    expect(find.text('Befrienders Kenya'), findsOneWidget);
    expect(find.text('Call 999'), findsOneWidget);
  });
}
