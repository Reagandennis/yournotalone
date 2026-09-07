import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/journal/journal_hub_screen.dart';
import 'package:yournotalone/journal/journal_repository.dart';
import 'package:yournotalone/onboarding/checkin_screen.dart';
import 'package:yournotalone/onboarding/paywall_screen.dart';
import 'package:yournotalone/onboarding/therapy_offer_screen.dart';

/// Reports a fixed entry count, so the free cap can be exercised without
/// a backend.
class _FullJournal extends JournalRepository {
  _FullJournal(this.count);
  final int count;

  @override
  Future<int> countEntries() async => count;
}

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

  testWidgets('every check-in answer ends up at the paywall', (tester) async {
    // The "struggling" branch used to finish onboarding at the therapy
    // offer, so half of all new users never saw pricing at all.
    tallScreen(tester);
    await tester.pumpWidget(wrap(const CheckinScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Struggling'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(TherapyOfferScreen), findsOneWidget);
    await tester.tap(find.text('Not right now'));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('the paywall can be left without downgrading', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(wrap(
      const Scaffold(body: PaywallScreen(checkin: 'steady')),
    ));
    await tester.pumpAndSettle();

    // Opened from Settings or an upgrade sheet: there is a close button,
    // and the secondary action is a dismissal, not "choose the free plan".
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Maybe later'), findsOneWidget);
    expect(find.text('Continue with Free'), findsNothing);
  });

  testWidgets('during onboarding it is a one-way door', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(wrap(
      const PaywallScreen(checkin: 'steady', fromOnboarding: true),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.text('Continue with Free'), findsOneWidget);
  });

  testWidgets('the plan table only claims what is actually gated',
      (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(wrap(
      const PaywallScreen(checkin: 'steady', fromOnboarding: true),
    ));
    await tester.pumpAndSettle();

    // Reminders and urge surfing are free; selling them as Premium was a
    // promise the app doesn't keep.
    expect(find.text('Daily reminders'), findsOneWidget);
    expect(find.text('Urge surfing, any time'), findsOneWidget);
    expect(find.text('Progress insights & reminders'), findsNothing);
  });

  testWidgets('the free journal cap holds from the hub too', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(wrap(
      JournalHubScreen(journal: _FullJournal(freeJournalEntryLimit)),
    ));
    await tester.pumpAndSettle();

    // "Free write" used to push the editor unconditionally, handing free
    // users unlimited entries.
    await tester.tap(find.text('Free write'));
    await tester.pumpAndSettle();
    expect(find.text('You\'ve filled your free pages'), findsOneWidget);
  });

  testWidgets('under the cap, writing still opens', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(wrap(JournalHubScreen(journal: _FullJournal(1))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Free write'));
    await tester.pumpAndSettle();
    expect(find.text('You\'ve filled your free pages'), findsNothing);
  });
}
