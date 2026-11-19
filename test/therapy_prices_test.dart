import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/session_payments.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/notifications/session_notifications.dart';
import 'package:yournotalone/support/countries.dart';
import 'package:yournotalone/therapy/country_signals.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';
import 'package:yournotalone/therapy/therapy_screen.dart';

final _now = DateTime(2026, 11, 11, 12);

Map<String, dynamic> _quoteJson({
  String? country = 'GB',
  bool canChange = true,
  String currency = 'GBP',
  int price = 4500,
  int charge = 760000,
}) => {
  'country': country,
  'can_change': canChange,
  'currency': currency,
  'price_minor': price,
  'charge_currency': 'KES',
  'charge_minor': charge,
  'priced_countries': ['GB', 'KE'],
};

final _prices = {
  'GB': _quoteJson(),
  'KE': _quoteJson(
    country: 'KE',
    currency: 'KES',
    price: 260000,
    charge: 260000,
  ),
  'US': _quoteJson(country: 'US', currency: 'USD', price: 2000, charge: 260000),
};

/// Apple's three-letter storefront codes this fake knows.
const _iso3 = {'GBR': 'GB', 'KEN': 'KE', 'USA': 'US'};

/// The pricing side of the database: a country per person, a price per
/// country, and a country that's fixed once they've paid. With [detects]
/// it has migration 0034 (the phone's signals set the country); without,
/// only 0031 (a country picked from a list).
class _PricedTherapy extends TherapyRepository {
  _PricedTherapy({
    this.country,
    this.locked = false,
    this.draftCents,
    this.draftCurrency,
    this.detects = false,
    this.source,
  });

  String? country;
  bool locked;
  final bool detects;

  /// Where [country] came from, as 0034 records it.
  String? source;

  final signalsSeen = <CountrySignals>[];

  /// What a saved draft is priced at; by [country] when null.
  final int? draftCents;
  final String? draftCurrency;

  final countriesSet = <String>[];
  final requests = <TherapyRequest>[];

  TherapyPriceQuote get _quote => TherapyPriceQuote.fromJson({
    ...(_prices[country] ?? _prices['US']!),
    'country': country,
    'source': source,
    'locked': locked,
    'can_change': !locked && (source == null || source == 'client'),
  });

  @override
  Future<TherapyPriceQuote> fetchPriceQuote() async => _quote;

  @override
  Future<TherapyPriceQuote> detectPriceCountry(CountrySignals signals) async {
    if (!detects) return TherapyPriceQuote.fallback;
    signalsSeen.add(signals);
    String? code(String? c) => c == null ? null : _iso3[c] ?? c;
    final picked = [
      ('store', code(signals.store)),
      ('sim', code(signals.sim)),
      ('region', code(signals.region)),
    ].where((p) => p.$2 != null).firstOrNull;
    if (picked != null && !locked && source != 'admin') {
      country = picked.$2;
      source = picked.$1;
    }
    return _quote;
  }

  @override
  Future<TherapyPriceQuote> setPriceCountry(String code) async {
    if (locked && code != country) {
      throw const PostgrestException(
        message:
            'Your country is set from your first session. Reply to any of '
            'our emails if it has changed.',
        code: 'P0001',
      );
    }
    countriesSet.add(code);
    country = code;
    return _quote;
  }

  @override
  Future<List<TherapyRequest>> fetchRequests() async => requests;

  @override
  Future<TherapyRequest> requestSession({
    required String topic,
    List<String> availability = const [],
    String? note,
  }) async {
    final quote = _quote;
    final draft = TherapyRequest(
      id: 'draft-${requests.length + 1}',
      topic: topic,
      availability: availability,
      note: note,
      status: 'awaiting_payment',
      isFreeSession: false,
      scheduledAt: null,
      createdAt: _now,
      priceCents: draftCents ?? quote.priceMinor,
      currency: draftCurrency ?? quote.currency,
      chargeMinor: quote.chargeMinor,
      chargeCurrency: quote.chargeCurrency,
      paymentStatus: 'unpaid',
    );
    requests.insert(0, draft);
    return draft;
  }

  @override
  Future<void> cancelRequest(String id) async =>
      requests.removeWhere((r) => r.id == id);

  @override
  Future<Map<String, TherapistProfile>> fetchTherapists(
    Iterable<String> ids,
  ) async => const {};

  @override
  Future<Map<String, int>> fetchMyRatings() async => const {};
}

class _FixedPayments extends SessionPayments {
  _FixedPayments(this.outcome, {required super.repository});

  final SessionPaymentOutcome outcome;
  final paidFor = <String>[];

  @override
  Future<SessionPaymentOutcome> pay(
    TherapyRequest request, {
    CheckoutWaiter? waitForCheckout,
  }) async {
    paidFor.add(request.id);
    return outcome;
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _show(WidgetTester tester, Widget screen) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(600, 3200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: screen));
  await _settle(tester);
}

TherapyScreen _screen(
  TherapyRepository repository, {
  SessionPayments? payments,
  String? device = 'GB',
  String? store,
}) => TherapyScreen(
  repository: repository,
  payments: payments,
  clock: () => _now,
  readCountrySignals: () async =>
      CountrySignals(store: store, region: device, platform: 'android'),
);

/// From the therapy screen through the first two steps to the review.
Future<void> _toReview(WidgetTester tester, {String topic = 'Low mood'}) async {
  await tester.tap(find.text('Request a session'));
  await _settle(tester);
  await tester.tap(find.text(topic));
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await _settle(tester);
  await tester.tap(find.text('Continue'));
  await _settle(tester);
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

  group('prices read the way the emails write them', () {
    test('in each currency\'s own sign, thousands grouped', () {
      expect(formatPrice(2000), '\$20');
      expect(formatPrice(2050, 'USD'), '\$20.50');
      expect(formatPrice(4500, 'GBP'), '£45');
      expect(formatPrice(4950, 'EUR'), '€49.50');
      expect(formatPrice(260000, 'KES'), 'Ksh 2,600');
      expect(formatPrice(760000, 'kes'), 'Ksh 7,600');
      expect(formatPrice(10000000, 'UGX'), 'USh 100,000');
      expect(formatPrice(123456789, 'KES'), 'Ksh 1,234,567.89');
      expect(formatPrice(5005, 'CHF'), 'CHF 50.05');
      expect(formatPrice(0, 'GBP'), '£0');
    });

    test('a session shows what Paystack will charge for it', () {
      final row = {
        'id': 'r1',
        'topic': 'Low mood',
        'availability': const <String>[],
        'status': 'awaiting_payment',
        'is_free_session': false,
        'created_at': '2026-11-11T09:00:00Z',
        'price_cents': 4500,
        'currency': 'GBP',
        'payment_status': 'unpaid',
      };
      final priced = TherapyRequest.fromRow({
        ...row,
        'charge_minor': 760000,
        'charge_currency': 'KES',
      });
      expect(priced.priceLabel, '£45');
      expect(priced.chargeLabel, 'Ksh 7,600');
      // Booked before prices by country: charged the old flat amount.
      expect(TherapyRequest.fromRow(row).chargeLabel, 'Ksh 2,600');
    });

    test('notifications use the session\'s currency when they have it', () {
      final data = {
        'role': 'client',
        'scheduled_at': '2026-11-12T11:00:00Z',
        'duration_minutes': 50,
        'payment_status': 'unpaid',
        'price_cents': 4500,
        'counterpart': 'Tess Mwangi',
      };
      expect(
        describeSessionNotification('session_booked', {
          ...data,
          'currency': 'GBP',
        }, _now).body,
        contains('Pay £45 in the app'),
      );
      expect(
        describeSessionNotification('session_booked', {
          ...data,
          'price_cents': 2000,
        }, _now).body,
        contains('Pay \$20 in the app'),
      );
    });
  });

  group('the price quote', () {
    test('reads the server\'s answer', () async {
      final quote = await readPriceQuote(() async => _quoteJson());
      expect(quote.fromServer, isTrue);
      expect(quote.country, 'GB');
      expect(quote.canChange, isTrue);
      expect(quote.priceLabel, '£45');
      expect(quote.chargeLabel, 'Ksh 7,600');
      expect(quote.pricedCountries, ['GB', 'KE']);
    });

    test('with no country yet, the default price', () async {
      final quote = await readPriceQuote(
        () async => _quoteJson(country: null, currency: 'USD', price: 2000),
      );
      expect(quote.country, isNull);
      expect(quote.priceLabel, '\$20');
    });

    test('today\'s price before the migration is applied', () async {
      final quote = await readPriceQuote(
        () async => throw const PostgrestException(
          message:
              'Could not find the function public.therapy_price_quote '
              'without parameters in the schema cache',
          code: 'PGRST202',
        ),
      );
      expect(quote.fromServer, isFalse);
      expect(quote.priceLabel, '\$20');
      expect(quote.chargeLabel, 'Ksh 2,600');
      expect(quote.canChange, isFalse);
    });

    test('today\'s price offline, or with an answer it can\'t read', () async {
      for (final call in <Future<Object?> Function()>[
        () async => throw http.ClientException('Failed host lookup'),
        () async => 'not a quote',
      ]) {
        final quote = await readPriceQuote(call);
        expect(quote.fromServer, isFalse);
        expect(quote.priceLabel, '\$20');
      }
    });

    Future<CountrySignals> Function() signals({
      String? store,
      String? sim,
      String? region,
    }) =>
        () async => CountrySignals(
          store: store,
          sim: sim,
          region: region,
          platform: 'android',
        );

    test(
      'the store account\'s country prices them, sent with the rest',
      () async {
        final repo = _PricedTherapy(detects: true);
        final quote = await loadTherapyPriceQuote(
          repo,
          readSignals: signals(store: 'GBR', sim: 'KE', region: 'US'),
        );
        expect(quote.country, 'GB');
        expect(quote.source, 'store');
        expect(quote.canChange, isFalse);
        expect(quote.priceLabel, '£45');
        expect(repo.signalsSeen.single.sim, 'KE');
        expect(repo.signalsSeen.single.region, 'US');
        // Nothing is picked from a list.
        expect(repo.countriesSet, isEmpty);
      },
    );

    test('with no store country, the SIM\'s, then the region\'s', () async {
      final sim = _PricedTherapy(detects: true);
      expect(
        (await loadTherapyPriceQuote(
          sim,
          readSignals: signals(sim: 'KE', region: 'US'),
        )).source,
        'sim',
      );
      final region = _PricedTherapy(detects: true);
      expect(
        (await loadTherapyPriceQuote(
          region,
          readSignals: signals(region: 'US'),
        )).country,
        'US',
      );
    });

    test('signals that can\'t be read still get a price', () async {
      final repo = _PricedTherapy(detects: true);
      final quote = await loadTherapyPriceQuote(
        repo,
        readSignals: () async => throw StateError('no RevenueCat'),
      );
      expect(repo.signalsSeen.single.isEmpty, isTrue);
      expect(quote.fromServer, isTrue);
      expect(quote.priceLabel, '\$20');
    });

    test('once paid for, or set by the care team, the country stays', () async {
      final paid = _PricedTherapy(detects: true, country: 'KE', locked: true);
      expect(
        (await loadTherapyPriceQuote(
          paid,
          readSignals: signals(store: 'GBR'),
        )).country,
        'KE',
      );
      final care = _PricedTherapy(
        detects: true,
        country: 'KE',
        source: 'admin',
      );
      expect(
        (await loadTherapyPriceQuote(
          care,
          readSignals: signals(store: 'GBR'),
        )).country,
        'KE',
      );
    });

    test('before detection exists, the phone\'s country is set quietly the '
        'first time', () async {
      final repo = _PricedTherapy();
      final quote = await loadTherapyPriceQuote(
        repo,
        readSignals: signals(store: 'KEN', region: 'KE'),
      );
      // Three-letter store codes are left to 0034.
      expect(repo.countriesSet, ['KE']);
      expect(quote.country, 'KE');
      expect(quote.priceLabel, 'Ksh 2,600');
    });

    test('before detection exists, a country already chosen, or fixed, is '
        'left alone', () async {
      final chosen = _PricedTherapy(country: 'GB');
      await loadTherapyPriceQuote(chosen, readSignals: signals(region: 'KE'));
      expect(chosen.countriesSet, isEmpty);

      final fixed = _PricedTherapy(locked: true);
      final quote = await loadTherapyPriceQuote(
        fixed,
        readSignals: signals(region: 'KE'),
      );
      expect(fixed.countriesSet, isEmpty);
      expect(quote.country, isNull);

      final unknown = _PricedTherapy();
      await loadTherapyPriceQuote(unknown, readSignals: signals());
      expect(unknown.countriesSet, isEmpty);
    });
  });

  group('country names', () {
    test('every country, by name, findable without accents', () {
      expect(countryName('GB'), 'United Kingdom');
      expect(countryName('ke'), 'Kenya');
      expect(countryName('ZW'), 'Zimbabwe');
      expect(countryName('QQ'), 'QQ');
      final choices = countryChoices(drafts: false);
      expect(choices.length, isoCountries.length);
      final turkey = choices.firstWhere((c) => c.code == 'TR');
      expect(countryMatches(turkey, 'turk'), isTrue);
      final ivory = choices.firstWhere((c) => c.code == 'CI');
      expect(countryMatches(ivory, 'cote'), isTrue);
      expect(countryMatches(ivory, 'kenya'), isFalse);
      // Sorted by name, accents beside plain letters.
      final names = [for (final c in choices) c.name];
      expect(
        names.indexOf('Åland Islands'),
        lessThan(names.indexOf('Albania')),
      );
    });
  });

  group('therapy screen', () {
    testWidgets('shows the price for their country, and where it came from', (
      tester,
    ) async {
      final repo = _PricedTherapy(detects: true);
      await _show(tester, _screen(repo, store: 'GB'));
      expect(find.text('£45 a session'), findsOneWidget);
      expect(
        find.text('Prices for United Kingdom, from your Google Play account'),
        findsOneWidget,
      );
      expect(find.text('Not right?'), findsOneWidget);
      // Detected, so there's no list to pick from.
      expect(find.text('Change'), findsNothing);
      expect(find.text('Request a session'), findsOneWidget);
    });

    testWidgets('"Not right?" says why, and how to have it changed', (
      tester,
    ) async {
      await _show(tester, _screen(_PricedTherapy(detects: true), store: 'GB'));
      await tester.tap(find.text('Not right?'));
      await _settle(tester);
      expect(find.text('Your price follows where you live'), findsOneWidget);
      expect(
        find.textContaining('from your Google Play account, so'),
        findsOneWidget,
      );
      expect(find.text('Email us'), findsOneWidget);
    });

    testWidgets('once paid for, it says the country is fixed', (tester) async {
      final repo = _PricedTherapy(
        detects: true,
        country: 'KE',
        locked: true,
        source: 'store',
      );
      await _show(tester, _screen(repo, store: 'GB'));
      expect(find.text('Prices for Kenya'), findsOneWidget);
      await tester.tap(find.text('Not right?'));
      await _settle(tester);
      expect(
        find.textContaining('set when you paid for your first session'),
        findsOneWidget,
      );
    });

    testWidgets('before detection exists, the first visit prices them by '
        'the phone\'s country', (tester) async {
      final repo = _PricedTherapy();
      await _show(tester, _screen(repo, device: 'GB'));
      expect(repo.countriesSet, ['GB']);
      expect(find.text('Prices for United Kingdom'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('with no country known, says prices depend on it', (
      tester,
    ) async {
      await _show(tester, _screen(_PricedTherapy(), device: null));
      expect(find.text('Prices depend on where you live'), findsOneWidget);
      expect(find.text('\$20 a session'), findsOneWidget);
    });

    testWidgets('picking a country from the list changes the price', (
      tester,
    ) async {
      final repo = _PricedTherapy(country: 'GB', source: 'client');
      await _show(tester, _screen(repo));
      await tester.tap(find.text('Change'));
      await _settle(tester);
      expect(find.text('Where do you live?'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'ken',
      );
      await tester.pump();
      await tester.tap(find.text('Kenya'));
      await _settle(tester);

      expect(repo.countriesSet, ['KE']);
      expect(find.text('Prices for Kenya'), findsOneWidget);
      expect(find.text('Ksh 2,600 a session'), findsOneWidget);
    });

    testWidgets('a refused change shows the database\'s reason', (
      tester,
    ) async {
      final repo = _PricedTherapy(country: 'GB', source: 'client');
      await _show(tester, _screen(repo));
      // They paid for a session elsewhere while this screen was open.
      repo.locked = true;
      await tester.tap(find.text('Change'));
      await _settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'kenya',
      );
      await tester.pump();
      await tester.tap(find.text('Kenya'));
      await _settle(tester);

      expect(
        find.text(
          'Your country is set from your first session. Reply to any of '
          'our emails if it has changed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Prices for United Kingdom'), findsOneWidget);
      expect(find.text('Change'), findsNothing);
    });
  });

  group('asking for a session', () {
    testWidgets('three steps: what, when, then the price to check', (
      tester,
    ) async {
      final repo = _PricedTherapy(detects: true);
      await _show(tester, _screen(repo, store: 'GB'));
      await tester.tap(find.text('Request a session'));
      await _settle(tester);

      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('What would you like to focus on?'), findsOneWidget);
      // Nothing chosen yet, so there's nowhere to go.
      final next = find.ancestor(
        of: find.text('Continue'),
        matching: find.byType(ElevatedButton),
      );
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
      await tester.tap(find.text('Anxiety & stress'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await _settle(tester);

      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('When could you meet?'), findsOneWidget);
      await tester.tap(find.text('Weekday evenings'));
      await tester.tap(find.text('Weekends'));
      await tester.enterText(find.byType(TextField), 'Evenings are best.');
      await tester.tap(find.text('Continue'));
      await _settle(tester);

      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Check and pay'), findsOneWidget);
      expect(find.text('Anxiety & stress'), findsOneWidget);
      expect(find.text('Weekday evenings, Weekends'), findsOneWidget);
      expect(find.text('Evenings are best.'), findsOneWidget);
      expect(find.text('£45'), findsOneWidget);
      expect(
        find.text('Prices for United Kingdom, from your Google Play account'),
        findsOneWidget,
      );
      // Charged in shillings, so it says so.
      expect(
        find.textContaining('Paystack charges this as Ksh 7,600'),
        findsOneWidget,
      );
      expect(find.text('Pay £45'), findsOneWidget);
    });

    testWidgets('a price in shillings needs no word about converting', (
      tester,
    ) async {
      await _show(tester, _screen(_PricedTherapy(detects: true), store: 'KEN'));
      await _toReview(tester);
      expect(find.text('Ksh 2,600'), findsOneWidget);
      expect(find.textContaining('Paystack charges this as'), findsNothing);
      expect(find.text('Any time'), findsOneWidget);
    });

    testWidgets('back goes back a step, keeping what was chosen', (
      tester,
    ) async {
      await _show(tester, _screen(_PricedTherapy(detects: true), store: 'GB'));
      await _toReview(tester, topic: 'Grief & loss');
      // "Change" beside the focus goes back to the first step.
      await tester.tap(find.text('Change').first);
      await _settle(tester);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await _settle(tester);
      expect(find.text('Request a session'), findsOneWidget);
      expect(find.text('Step 1 of 3'), findsNothing);
    });

    testWidgets('a request priced differently from the flow isn\'t sent '
        'straight to payment', (tester) async {
      final repo = _PricedTherapy(
        detects: true,
        draftCents: 5000,
        draftCurrency: 'GBP',
      );
      final payments = _FixedPayments(
        SessionPaymentOutcome.paid,
        repository: repo,
      );
      await _show(tester, _screen(repo, payments: payments, store: 'GB'));
      await _toReview(tester);
      await tester.tap(find.text('Pay £45'));
      await _settle(tester);

      expect(payments.paidFor, isEmpty);
      expect(
        find.text('The session price is £50. Check it before you pay.'),
        findsWidgets,
      );
      // Back on the therapy screen, with the request at its own price.
      expect(find.text('£50 — pay to send your request'), findsOneWidget);
    });

    testWidgets('a request priced as shown goes straight to payment', (
      tester,
    ) async {
      final repo = _PricedTherapy(detects: true);
      final payments = _FixedPayments(
        SessionPaymentOutcome.cancelled,
        repository: repo,
      );
      await _show(tester, _screen(repo, payments: payments, store: 'GB'));
      await _toReview(tester);
      await tester.tap(find.text('Pay £45'));
      await _settle(tester);
      expect(payments.paidFor, ['draft-1']);
      // Backed out of the checkout: the draft stays on the therapy screen,
      // at its price, to pay or discard (an M-Pesa prompt can still be
      // approved after the page closes).
      expect(find.text('Check and pay'), findsNothing);
      expect(find.text('£45 — pay to send your request'), findsOneWidget);
    });
  });
}
