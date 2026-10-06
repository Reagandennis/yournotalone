import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/session_payments.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';
import 'package:yournotalone/therapy/therapy_screen.dart';

final _now = DateTime(2026, 9, 14, 12);

TherapyRequest _request() => TherapyRequest(
  id: 'r1',
  topic: 'Anxiety & stress',
  availability: const ['Weekends'],
  note: null,
  status: 'confirmed',
  isFreeSession: false,
  scheduledAt: _now.add(const Duration(hours: 2)),
  createdAt: _now.subtract(const Duration(days: 1)),
  therapistId: 't1',
  priceCents: 2000,
  paymentStatus: 'unpaid',
);

const _therapist = TherapistProfile(
  id: 't1',
  fullName: 'Tess Mwangi',
  title: 'Counselling psychologist',
  specialties: ['Anxiety & stress'],
  ratingAverage: 4.5,
  ratingCount: 6,
);

/// The server side: each confirm call pops the next scripted answer.
/// `null` means the payment was found; a string is the error code.
class _ScriptedServer extends TherapyRepository {
  _ScriptedServer(this.answers);

  final List<String?> answers;
  var confirms = 0;

  @override
  Future<List<TherapyRequest>> fetchRequests() async => [_request()];

  @override
  Future<Map<String, TherapistProfile>> fetchTherapists(
    Iterable<String> ids,
  ) async => const {'t1': _therapist};

  @override
  Future<Map<String, int>> fetchMyRatings() async => const {};

  var checkouts = 0;

  @override
  Future<Uri?> startCheckout(String requestId) async {
    checkouts++;
    return Uri.parse('https://checkout.paystack.com/abc');
  }

  @override
  Future<void> confirmPayment(String requestId) async {
    confirms++;
    final code = answers.isEmpty ? 'no_payment_found' : answers.removeAt(0);
    if (code != null) throw SessionAccessException(code);
  }
}

class _FakeBrowser implements CheckoutBrowser {
  _FakeBrowser({this.opens = true});

  final bool opens;
  final opened = <Uri>[];
  var closes = 0;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return opens;
  }

  @override
  Future<void> close() async => closes++;
}

SessionPayments _payments(_ScriptedServer server, _FakeBrowser browser) =>
    SessionPayments(
      repository: server,
      browser: browser,
      currentUserId: () => 'user-1',
      wait: (_) async {},
    );

/// Stands in for the waiting dialog: asks the server [checks] times, then
/// gives up unless one of them found the payment.
CheckoutWaiter _waiter(int checks) => (checkPaid) async {
  for (var i = 0; i < checks; i++) {
    if (await checkPaid()) return true;
  }
  return false;
};

class _FixedPayments extends SessionPayments {
  _FixedPayments(this.outcome, {required super.repository});

  final SessionPaymentOutcome outcome;
  var calls = 0;

  @override
  Future<SessionPaymentOutcome> pay(
    TherapyRequest request, {
    CheckoutWaiter? waitForCheckout,
  }) async {
    calls++;
    return outcome;
  }
}

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
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

  group('paying for a session', () {
    test('opens the Paystack checkout and finds the payment', () async {
      final server = _ScriptedServer([
        'no_payment_found',
        'no_payment_found',
        null,
      ]);
      final browser = _FakeBrowser();
      final outcome = await _payments(
        server,
        browser,
      ).pay(_request(), waitForCheckout: _waiter(5));
      expect(outcome, SessionPaymentOutcome.paid);
      expect(browser.opened.single.host, 'checkout.paystack.com');
      expect(browser.closes, 1);
      // One check before opening, two while waiting.
      expect(server.confirms, 3);
    });

    test('never opens a checkout when nobody is signed in', () async {
      final server = _ScriptedServer([]);
      final browser = _FakeBrowser();
      final payments = SessionPayments(
        repository: server,
        browser: browser,
        currentUserId: () => null,
        wait: (_) async {},
      );
      await expectLater(
        payments.pay(_request()),
        throwsA(
          isA<SessionAccessException>().having(
            (e) => e.code,
            'code',
            'invalid_token',
          ),
        ),
      );
      expect(server.checkouts, 0);
    });

    test(
      'uses a payment that is already waiting instead of charging again',
      () async {
        final server = _ScriptedServer([null]);
        final browser = _FakeBrowser();
        final outcome = await _payments(server, browser).pay(_request());
        expect(outcome, SessionPaymentOutcome.paid);
        expect(server.checkouts, 0);
        expect(browser.opened, isEmpty);
      },
    );

    test(
      'doesn\'t open a checkout when the server can\'t be asked first',
      () async {
        final server = _ScriptedServer(['unavailable']);
        final browser = _FakeBrowser();
        await expectLater(
          _payments(server, browser).pay(_request()),
          throwsA(isA<SessionAccessException>()),
        );
        expect(server.checkouts, 0);
      },
    );

    test('leaving the checkout without paying is not an error', () async {
      final server = _ScriptedServer([]);
      final browser = _FakeBrowser();
      final outcome = await _payments(
        server,
        browser,
      ).pay(_request(), waitForCheckout: _waiter(2));
      expect(outcome, SessionPaymentOutcome.cancelled);
      expect(browser.closes, 1);
      // Before, twice while waiting, and once more after giving up.
      expect(server.confirms, 4);
    });

    test('a payment that lands as they give up still counts', () async {
      final server = _ScriptedServer(['no_payment_found', null]);
      final outcome = await _payments(
        server,
        _FakeBrowser(),
      ).pay(_request(), waitForCheckout: _waiter(0));
      expect(outcome, SessionPaymentOutcome.paid);
    });

    test('unavailable when the checkout page can\'t be opened', () async {
      final server = _ScriptedServer([]);
      expect(
        await _payments(server, _FakeBrowser(opens: false)).pay(_request()),
        SessionPaymentOutcome.unavailable,
      );
    });
  });

  group('session card after a pending payment', () {
    testWidgets('offers "Check payment" instead of "Pay" until the server '
        'says there is nothing to find', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 3200);
      addTearDown(tester.view.reset);
      // First check: still nothing. Second check: the server has looked.
      final server = _ScriptedServer(['no_payment_found']);
      final payments = _FixedPayments(
        SessionPaymentOutcome.pendingVerification,
        repository: server,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: TherapyScreen(
            repository: server,
            payments: payments,
            clock: () => _now,
          ),
        ),
      );
      await _settle(tester);

      expect(_button('Pay \$20'), findsOneWidget);
      await tester.tap(_button('Pay \$20'));
      await _settle(tester);

      expect(payments.calls, 1);
      expect(_button('Pay \$20'), findsNothing);
      expect(find.text('Already paid? Check again'), findsNothing);
      expect(_button('Check payment'), findsOneWidget);
      expect(find.textContaining('Don\'t pay again'), findsOneWidget);

      await tester.tap(_button('Check payment'));
      await _settle(tester);

      // The server looked and found nothing, so paying is offered again.
      expect(server.confirms, 1);
      expect(_button('Pay \$20'), findsOneWidget);
      expect(_button('Check payment'), findsNothing);
    });
  });
}
