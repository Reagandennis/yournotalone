import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/session_payments.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/notifications/session_notifications.dart';
import 'package:yournotalone/support/countries.dart';
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

/// The pricing side of the database: a country per person, a price per
/// country, and a country that's fixed once they've paid.
class _PricedTherapy extends TherapyRepository {
  _PricedTherapy({
    this.country,
    this.locked = false,
    this.draftCents,
    this.draftCurrency,
  });

  String? country;
  bool locked;

  /// What a saved draft is priced at; by [country] when null.
  final int? draftCents;
  final String? draftCurrency;

  final countriesSet = <String>[];
  final requests = <TherapyRequest>[];

  TherapyPriceQuote get _quote => TherapyPriceQuote.fromJson({
    ...(_prices[country] ?? _prices['US']!),
    'country': country,
    'can_change': !locked,
  });

  @override
  Future<TherapyPriceQuote> fetchPriceQuote() async => _quote;

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
}) => TherapyScreen(
  repository: repository,
  payments: payments,
  clock: () => _now,
  detectCountry: () => device,
);

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

    test('the first time, the phone\'s country is set quietly', () async {
      final repo = _PricedTherapy();
      final quote = await loadTherapyPriceQuote(
        repo,
        detectCountry: () => 'KE',
      );
      expect(repo.countriesSet, ['KE']);
      expect(quote.country, 'KE');
      expect(quote.priceLabel, 'Ksh 2,600');
    });

    test('a country already chosen, or fixed, is left alone', () async {
      final chosen = _PricedTherapy(country: 'GB');
      await loadTherapyPriceQuote(chosen, detectCountry: () => 'KE');
      expect(chosen.countriesSet, isEmpty);

      final fixed = _PricedTherapy(locked: true);
      final quote = await loadTherapyPriceQuote(
        fixed,
        detectCountry: () => 'KE',
      );
      expect(fixed.countriesSet, isEmpty);
      expect(quote.country, isNull);

      final unknown = _PricedTherapy();
      await loadTherapyPriceQuote(unknown, detectCountry: () => null);
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

  group('booking screen', () {
    testWidgets('shows the price for their country, and what Paystack '
        'charges', (tester) async {
      await _show(tester, _screen(_PricedTherapy(country: 'GB')));
      expect(find.text('Sessions are £45, paid when you book'), findsOneWidget);
      expect(find.text('Pay £45 and request a session'), findsOneWidget);
      expect(find.textContaining('charged as Ksh 7,600'), findsOneWidget);
      expect(find.text('Prices for United Kingdom'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('the first visit prices them by the phone\'s country', (
      tester,
    ) async {
      final repo = _PricedTherapy();
      await _show(tester, _screen(repo, device: 'GB'));
      expect(repo.countriesSet, ['GB']);
      expect(find.text('Prices for United Kingdom'), findsOneWidget);
    });

    testWidgets('with no country known, says prices depend on it', (
      tester,
    ) async {
      await _show(tester, _screen(_PricedTherapy(), device: null));
      expect(find.text('Prices depend on where you live'), findsOneWidget);
      expect(find.text('Pay \$20 and request a session'), findsOneWidget);
    });

    testWidgets('changing country changes the price', (tester) async {
      final repo = _PricedTherapy(country: 'GB');
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
      expect(find.text('Pay Ksh 2,600 and request a session'), findsOneWidget);
    });

    testWidgets('once paid for, the country can\'t be changed here', (
      tester,
    ) async {
      await _show(tester, _screen(_PricedTherapy(country: 'GB', locked: true)));
      expect(find.text('Prices for United Kingdom'), findsOneWidget);
      expect(find.text('Change'), findsNothing);
    });

    testWidgets('a refused change shows the database\'s reason', (
      tester,
    ) async {
      final repo = _PricedTherapy(country: 'GB');
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

    testWidgets('a request priced differently from the form isn\'t sent '
        'straight to payment', (tester) async {
      final repo = _PricedTherapy(
        country: 'GB',
        draftCents: 5000,
        draftCurrency: 'GBP',
      );
      final payments = _FixedPayments(
        SessionPaymentOutcome.paid,
        repository: repo,
      );
      await _show(tester, _screen(repo, payments: payments));
      await tester.tap(find.text('Anxiety & stress'));
      await tester.pump();
      await tester.tap(find.text('Pay £45 and request a session'));
      await _settle(tester);

      expect(payments.paidFor, isEmpty);
      expect(
        find.text('The session price is £50. Check it before you pay.'),
        findsOneWidget,
      );
      expect(find.text('£50 — pay to send your request'), findsOneWidget);
      expect(find.textContaining('charged as Ksh 7,600'), findsOneWidget);
    });

    testWidgets('a request priced as shown goes straight to payment', (
      tester,
    ) async {
      final repo = _PricedTherapy(country: 'GB');
      final payments = _FixedPayments(
        SessionPaymentOutcome.cancelled,
        repository: repo,
      );
      await _show(tester, _screen(repo, payments: payments));
      await tester.tap(find.text('Anxiety & stress'));
      await tester.pump();
      await tester.tap(find.text('Pay £45 and request a session'));
      await _settle(tester);
      expect(payments.paidFor, ['draft-1']);
    });
  });
}
