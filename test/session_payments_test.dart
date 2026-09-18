import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
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
          Iterable<String> ids) async =>
      const {'t1': _therapist};

  @override
  Future<Map<String, int>> fetchMyRatings() async => const {};

  @override
  Future<void> confirmPayment(String requestId) async {
    confirms++;
    final code = answers.isEmpty ? 'no_payment_found' : answers.removeAt(0);
    if (code != null) throw SessionAccessException(code);
  }
}

class _FakeStore implements SessionStore {
  _FakeStore({
    this.available = true,
    this.identityError,
    this.buyError,
    this.forSale = true,
  });

  final bool available;
  final Object? identityError;
  final Object? buyError;
  final bool forSale;
  final identities = <String>[];
  var buys = 0;

  @override
  bool get isAvailable => available;

  @override
  Future<void> ensureIdentity(String userId) async {
    if (identityError != null) throw identityError!;
    identities.add(userId);
  }

  @override
  Future<bool> buy() async {
    if (buyError != null) throw buyError!;
    buys++;
    return forSale;
  }
}

PlatformException _storeError(PurchasesErrorCode code) =>
    PlatformException(code: '${code.index}', message: code.name);

SessionPayments _payments(_ScriptedServer server, _FakeStore store) =>
    SessionPayments(
      repository: server,
      store: store,
      currentUserId: () => 'user-1',
      wait: (_) async {},
    );

class _FixedPayments extends SessionPayments {
  _FixedPayments(this.outcome, {required super.repository});

  final SessionPaymentOutcome outcome;
  var calls = 0;

  @override
  Future<SessionPaymentOutcome> pay(TherapyRequest request) async {
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
    test('ties the store customer to the signed-in user before buying',
        () async {
      final server = _ScriptedServer(['no_payment_found', null]);
      final store = _FakeStore();
      final outcome = await _payments(server, store).pay(_request());
      expect(outcome, SessionPaymentOutcome.paid);
      expect(store.identities, ['user-1']);
      expect(store.buys, 1);
    });

    test('never buys when the store identity can\'t be set', () async {
      final server = _ScriptedServer([]);
      final store = _FakeStore(
        identityError: _storeError(PurchasesErrorCode.networkError),
      );
      await expectLater(
        _payments(server, store).pay(_request()),
        throwsA(isA<PlatformException>()),
      );
      expect(store.buys, 0);
      expect(server.confirms, 0);
    });

    test('never buys when nobody is signed in', () async {
      final server = _ScriptedServer([]);
      final store = _FakeStore();
      final payments = SessionPayments(
        repository: server,
        store: store,
        currentUserId: () => null,
        wait: (_) async {},
      );
      await expectLater(
        payments.pay(_request()),
        throwsA(isA<SessionAccessException>()
            .having((e) => e.code, 'code', 'invalid_token')),
      );
      expect(store.buys, 0);
    });

    test('uses a purchase that is already waiting instead of charging again',
        () async {
      final server = _ScriptedServer([null]);
      final store = _FakeStore();
      final outcome = await _payments(server, store).pay(_request());
      expect(outcome, SessionPaymentOutcome.paid);
      expect(store.buys, 0);
      expect(server.confirms, 1);
    });

    test('doesn\'t buy when the server can\'t be asked first', () async {
      final server = _ScriptedServer(['unavailable']);
      final store = _FakeStore();
      await expectLater(
        _payments(server, store).pay(_request()),
        throwsA(isA<SessionAccessException>()),
      );
      expect(store.buys, 0);
    });

    test('backing out of the store sheet is not an error', () async {
      final server = _ScriptedServer(['no_payment_found']);
      final store = _FakeStore(
        buyError: _storeError(PurchasesErrorCode.purchaseCancelledError),
      );
      final outcome = await _payments(server, store).pay(_request());
      expect(outcome, SessionPaymentOutcome.cancelled);
      expect(server.confirms, 1);
    });

    test('reports a payment the server hasn\'t seen after retrying',
        () async {
      final server = _ScriptedServer([]);
      final store = _FakeStore();
      final outcome = await _payments(server, store).pay(_request());
      expect(outcome, SessionPaymentOutcome.pendingVerification);
      expect(store.buys, 1);
      // One check before buying, three after.
      expect(server.confirms, 4);
    });

    test('unavailable when the product isn\'t for sale or the store is off',
        () async {
      expect(
        await _payments(_ScriptedServer([]), _FakeStore(forSale: false))
            .pay(_request()),
        SessionPaymentOutcome.unavailable,
      );
      final off = _FakeStore(available: false);
      expect(
        await _payments(_ScriptedServer([]), off).pay(_request()),
        SessionPaymentOutcome.unavailable,
      );
      expect(off.identities, isEmpty);
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
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: TherapyScreen(
          repository: server,
          payments: payments,
          clock: () => _now,
        ),
      ));
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
