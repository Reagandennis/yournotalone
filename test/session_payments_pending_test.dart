import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/purchases_service.dart';
import 'package:yournotalone/billing/session_payments.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/notifications/session_notifications.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';
import 'package:yournotalone/therapy/therapy_screen.dart';

final _now = DateTime(2026, 9, 14, 12);

TherapyRequest _request({
  String id = 'r1',
  String status = 'confirmed',
  String paymentStatus = 'unpaid',
  DateTime? scheduledAt,
}) => TherapyRequest(
  id: id,
  topic: 'Anxiety & stress',
  availability: const ['Weekends'],
  note: null,
  status: status,
  isFreeSession: false,
  scheduledAt: status == 'confirmed'
      ? (scheduledAt ?? _now.add(const Duration(days: 3)))
      : null,
  createdAt: _now.subtract(const Duration(days: 1)),
  therapistId: status == 'confirmed' ? 't1' : null,
  priceCents: 2000,
  paymentStatus: paymentStatus,
);

const _therapist = TherapistProfile(
  id: 't1',
  fullName: 'Tess Mwangi',
  title: 'Counselling psychologist',
  specialties: ['Anxiety & stress'],
);

class _Server extends TherapyRepository {
  _Server(this.request, {this.startError, this.confirmError = 'no_payment_found'});

  final TherapyRequest request;

  /// Thrown by [startCheckout] when set.
  final String? startError;

  /// What [confirmPayment] throws; null means the payment was found.
  String? confirmError;

  var checkouts = 0;
  var confirms = 0;
  final cancelled = <String>[];

  @override
  Future<List<TherapyRequest>> fetchRequests() async => [request];

  @override
  Future<Map<String, TherapistProfile>> fetchTherapists(
    Iterable<String> ids,
  ) async => const {'t1': _therapist};

  @override
  Future<Map<String, int>> fetchMyRatings() async => const {};

  @override
  Future<Uri?> startCheckout(String requestId) async {
    checkouts++;
    if (startError != null) {
      throw SessionAccessException(startError!, reference: 'ref_1');
    }
    return Uri.parse('https://checkout.paystack.com/abc');
  }

  @override
  Future<void> confirmPayment(String requestId) async {
    confirms++;
    if (confirmError != null) throw SessionAccessException(confirmError!);
  }

  @override
  Future<void> cancelRequest(String id) async => cancelled.add(id);
}

/// Says a checkout opened at [opened] is still being paid.
class _OpenedServer extends _Server {
  _OpenedServer(super.request, this.opened);

  final DateTime opened;

  @override
  Future<Uri?> startCheckout(String requestId) async {
    checkouts++;
    throw SessionAccessException('payment_in_progress', openedAt: opened);
  }
}

class _Browser implements CheckoutBrowser {
  var opens = 0;

  @override
  Future<bool> open(Uri url) async {
    opens++;
    return true;
  }

  @override
  Future<void> close() async {}
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  SessionPayments payments(_Server server, {PendingCheckouts? pending}) =>
      SessionPayments(
        repository: server,
        browser: _Browser(),
        currentUserId: () => 'user-1',
        wait: (_) async {},
        pending: pending,
      );

  Future<void> pumpScreen(
    WidgetTester tester,
    _Server server,
    SessionPayments payments,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 3200);
    addTearDown(tester.view.reset);
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
  }

  group('the start answer', () {
    test('only paid: true means paid', () {
      expect(checkoutPageFrom({'paid': true}), isNull);
      expect(
        checkoutPageFrom({
          'authorization_url': 'https://checkout.paystack.com/x',
          'reference': 'r',
        }),
        Uri.parse('https://checkout.paystack.com/x'),
      );
    });

    test('a 2xx without a checkout page is a failed checkout', () {
      for (final data in <Map<String, dynamic>>[
        {},
        {'paid': false},
        {'authorization_url': ''},
        {'authorization_url': 42},
      ]) {
        expect(
          () => checkoutPageFrom(data),
          throwsA(
            isA<SessionAccessException>().having(
              (e) => e.code,
              'code',
              'checkout_failed',
            ),
          ),
          reason: '$data',
        );
      }
    });
  });

  group('a checkout left open', () {
    test('is remembered, on disk, for ten minutes', () async {
      var now = _now;
      final pending = PendingCheckouts(clock: () => now);
      final server = _Server(_request());
      final outcome = await payments(
        server,
        pending: pending,
      ).pay(_request(), waitForCheckout: (_) async => false);
      expect(outcome, SessionPaymentOutcome.cancelled);
      expect((await pending.openedAmong(['r1'])).keys, ['r1']);

      // A fresh start reads the same note.
      final again = PendingCheckouts(clock: () => now);
      expect((await again.openedAmong(['r1'])).keys, ['r1']);

      now = _now.add(const Duration(minutes: 11));
      expect(await pending.openedAmong(['r1']), isEmpty);
    });

    test('is forgotten once its payment is found', () async {
      final pending = PendingCheckouts();
      await pending.mark('r1');
      final server = _Server(_request(), confirmError: null);
      final outcome = await payments(server, pending: pending).pay(_request());
      expect(outcome, SessionPaymentOutcome.paid);
      expect(await pending.openedAmong(['r1']), isEmpty);
    });

    test('a checkout still in progress on the server is waited for', () async {
      final pending = PendingCheckouts();
      final server = _Server(_request(), startError: 'payment_in_progress');
      await expectLater(
        payments(server, pending: pending).pay(_request()),
        throwsA(
          isA<SessionAccessException>()
              .having((e) => e.code, 'code', 'payment_in_progress')
              .having((e) => e.reference, 'reference', 'ref_1'),
        ),
      );
      expect((await pending.openedAmong(['r1'])).keys, ['r1']);
    });

    test('a checkout in progress is waited for from when it opened', () async {
      final pending = PendingCheckouts(clock: () => _now);
      final opened = _now.subtract(const Duration(minutes: 9));
      final server = _OpenedServer(_request(), opened);
      await expectLater(
        payments(server, pending: pending).pay(_request()),
        throwsA(isA<SessionAccessException>()),
      );
      expect(await pending.openedAmong(['r1']), {'r1': opened});
    });
  });

  group('the session card', () {
    testWidgets('offers "Check payment", not "Pay", after leaving the '
        'checkout — and still does after a restart', (tester) async {
      final server = _Server(_request());
      final p = SessionPayments(
        repository: server,
        browser: _Browser(),
        currentUserId: () => 'user-1',
        wait: (_) async {},
      );
      await pumpScreen(tester, server, p);
      expect(_button('Pay \$20'), findsOneWidget);
      // The checkout dialog's "close" stands in for leaving the page.
      await tester.tap(_button('Pay \$20'));
      await _settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ));
      await _settle(tester);
      expect(server.checkouts, 1);
      expect(_button('Pay \$20'), findsNothing);
      expect(_button('Check payment'), findsOneWidget);
      expect(find.textContaining('Don\'t pay again'), findsOneWidget);

      // The app is closed and opened again.
      await tester.pumpWidget(const SizedBox());
      await pumpScreen(tester, server, payments(server));
      expect(_button('Pay \$20'), findsNothing);
      expect(_button('Check payment'), findsOneWidget);

      // A check that finds nothing puts paying back.
      await tester.tap(_button('Check payment'));
      await _settle(tester);
      expect(_button('Pay \$20'), findsOneWidget);
      expect(_button('Check payment'), findsNothing);
    });

    testWidgets('a 409 from the server shows "Check payment" and says the '
        'last payment is still going through', (tester) async {
      final server = _Server(_request(), startError: 'payment_in_progress');
      await pumpScreen(tester, server, payments(server));
      await tester.tap(_button('Pay \$20'));
      await _settle(tester);
      expect(find.textContaining('still being processed'), findsOneWidget);
      expect(_button('Check payment'), findsOneWidget);
      expect(_button('Pay \$20'), findsNothing);
    });

    testWidgets('discarding a draft within the window checks first, and '
        'keeps it when the check can\'t be made', (tester) async {
      final draft = _request(status: 'awaiting_payment');
      final server = _Server(draft, confirmError: 'unavailable');
      final p = payments(server);
      await p.pending.mark(draft.id);
      await pumpScreen(tester, server, p);
      expect(_button('Check payment'), findsOneWidget);

      await tester.tap(find.text('Discard').last);
      await _settle(tester);
      expect(find.textContaining('check whether that payment went through'),
          findsOneWidget);
      await tester.tap(find.text('Discard').last);
      await _settle(tester);
      expect(server.confirms, 1);
      expect(server.cancelled, isEmpty);
      expect(find.textContaining('the request is kept'), findsOneWidget);
    });

    testWidgets('a check while a checkout is still being paid keeps '
        '"Check payment"', (tester) async {
      final server = _Server(_request());
      final p = payments(server);
      await p.pending.mark('r1');
      await pumpScreen(tester, server, p);
      server.confirmError = 'payment_in_progress';
      await tester.tap(_button('Check payment'));
      await _settle(tester);
      expect(_button('Check payment'), findsOneWidget);
      expect(_button('Pay \$20'), findsNothing);
      expect((await p.pending.openedAmong(['r1'])).keys, ['r1']);
    });

    testWidgets('discarding a draft while its checkout is still being paid '
        'keeps it, even after the window', (tester) async {
      final draft = _request(status: 'awaiting_payment');
      final server = _Server(draft, confirmError: 'payment_in_progress');
      await pumpScreen(tester, server, payments(server));
      await tester.tap(find.text('Discard').last);
      await _settle(tester);
      await tester.tap(find.text('Discard').last);
      await _settle(tester);
      expect(server.confirms, 1);
      expect(server.cancelled, isEmpty);
      expect(find.textContaining('still being processed'), findsOneWidget);
    });

    testWidgets('discarding a draft whose payment turned up keeps it', (
      tester,
    ) async {
      final draft = _request(status: 'awaiting_payment');
      final server = _Server(draft);
      final p = payments(server);
      await p.pending.mark(draft.id);
      await pumpScreen(tester, server, p);
      server.confirmError = null;
      await tester.tap(find.text('Discard').last);
      await _settle(tester);
      await tester.tap(find.text('Discard').last);
      await _settle(tester);
      expect(server.cancelled, isEmpty);
    });
  });

  group('the cancel dialog', () {
    Future<String> dialogBody(WidgetTester tester, TherapyRequest r) async {
      final server = _Server(r);
      await pumpScreen(tester, server, payments(server));
      final action = r.isConfirmed ? 'Cancel session' : 'Cancel request';
      await tester.tap(find.text(action).last);
      await _settle(tester);
      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      return (dialog.content! as Text).data!;
    }

    testWidgets('promises a refund only for a paid session', (tester) async {
      expect(
        await dialogBody(tester, _request(paymentStatus: 'paid')),
        contains('refund your \$20'),
      );
    });

    for (final status in ['waived', 'not_required', 'unpaid']) {
      testWidgets('says nothing was charged for a $status session', (
        tester,
      ) async {
        final body = await dialogBody(tester, _request(paymentStatus: status));
        expect(body, contains('Nothing was charged'));
        expect(body, isNot(contains('\$20')));
      });
    }

    testWidgets('and for a waived request not yet matched', (tester) async {
      final body = await dialogBody(
        tester,
        _request(status: 'pending', paymentStatus: 'waived'),
      );
      expect(body, contains('Nothing was charged'));
    });
  });

  group('RevenueCat answers', () {
    test('apply only to the signed-in account', () {
      expect(customerMatchesAccount(appUserId: 'u1', accountId: 'u1'), isTrue);
      // logIn failed: still the last person's customer.
      expect(customerMatchesAccount(appUserId: 'u0', accountId: 'u1'), isFalse);
      expect(
        customerMatchesAccount(
          appUserId: r'$RCAnonymousID:abc',
          accountId: 'u1',
        ),
        isFalse,
      );
      expect(
        customerMatchesAccount(
          appUserId: r'$RCAnonymousID:abc',
          accountId: null,
        ),
        isTrue,
      );
      // logOut failed: the last person's Premium isn't the signed-out app's.
      expect(customerMatchesAccount(appUserId: 'u0', accountId: null), isFalse);
    });
  });

  group('phone reminders', () {
    final soon = _now.add(const Duration(hours: 2)).toUtc().toIso8601String();
    final past = _now
        .subtract(const Duration(minutes: 5))
        .toUtc()
        .toIso8601String();

    test('one the system dropped is no longer taken as scheduled', () {
      final stored = {'a': soon, 'b': soon};
      final kept = keepStillScheduled(
        stored,
        {reminderNotificationId('a')},
        _now,
      );
      expect(kept, {'a': soon});
      // So it's planned again.
      final plan = planSessionReminders(
        [
          {'request_id': 'b', 'scheduled_at': soon},
          {'request_id': 'a', 'scheduled_at': soon},
        ],
        kept,
        _now,
      );
      expect(plan.schedule.map((s) => s['request_id']), ['b']);
    });

    test('one that has fired stays taken as done', () {
      final kept = keepStillScheduled({'a': past}, const {}, _now);
      expect(kept, {'a': past});
    });
  });
}
