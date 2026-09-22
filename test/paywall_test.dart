import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/purchases_service.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/home_ui.dart';
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

  test('a comp grant unlocks premium even while billing is live', () {
    // Regression guard: making RevenueCat the source of truth locked out
    // the accounts we grant premium to by hand — our own, testers, and the
    // Play reviewer. `premium_comp` is the deliberate way back in, and
    // nothing in the app ever writes it.
    expect(compPremiumKey, 'premium_comp');

    // Without a session there is no metadata and nothing to grant, so the
    // answer is a plain no rather than an accidental yes.
    expect(isPremiumUser(), isFalse);
  });

  test('only app metadata can grant premium', () {
    User account({
      Map<String, dynamic> app = const {},
      Map<String, dynamic> user = const {},
    }) =>
        User(
          id: 'u1',
          appMetadata: app,
          userMetadata: user,
          aud: 'authenticated',
          createdAt: '2026-09-17T00:00:00Z',
        );

    // A grant we set by SQL lives in app metadata, which only the service
    // role can write.
    expect(isPremiumUser(account(app: {compPremiumKey: true})), isTrue);

    // The same key in user metadata is worthless: any signed-in user can
    // put it there through the public auth API, which is how premium used
    // to be self-grantable.
    expect(isPremiumUser(account(user: {compPremiumKey: true})), isFalse);

    // Picking a plan at the paywall isn't paying for it, on any platform.
    expect(
      isPremiumUser(account(user: {'plan_choice': 'premium_monthly'})),
      isFalse,
    );
    expect(isPremiumUser(account()), isFalse);
  });

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

  /// A home screen with a button that opens the paywall, so leaving it
  /// can be observed.
  Widget upgradeFromHome() => MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PaywallScreen(checkin: 'steady')),
              ),
              child: const Text('Upgrade'),
            ),
          ),
        ),
      );

  testWidgets('a subscriber is never sold Premium again', (tester) async {
    // On a new device the entitlement is known a moment after sign-in;
    // the paywall used to ignore it, show the trial, and the purchase
    // ended in Play's "already owned" error.
    tallScreen(tester);
    PurchasesService.instance.isPro.value = true;
    addTearDown(() => PurchasesService.instance.isPro.value = false);
    await tester.pumpWidget(upgradeFromHome());
    await tester.tap(find.text('Upgrade'));
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsNothing);
    expect(find.textContaining('already have Premium'), findsOneWidget);
  });

  testWidgets('the entitlement arriving while open closes the paywall',
      (tester) async {
    tallScreen(tester);
    addTearDown(() => PurchasesService.instance.isPro.value = false);
    await tester.pumpWidget(upgradeFromHome());
    await tester.tap(find.text('Upgrade'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);

    PurchasesService.instance.isPro.value = true;
    await tester.pumpAndSettle();

    expect(find.byType(PaywallScreen), findsNothing);
    expect(find.textContaining('already have Premium'), findsOneWidget);
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
