import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/session_payments.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/care/care_dashboard_screen.dart';
import 'package:yournotalone/care/care_repository.dart';
import 'package:yournotalone/care/therapist_sessions_screen.dart';
import 'package:yournotalone/therapy/call_keep_alive.dart';
import 'package:yournotalone/therapy/call_screen.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';
import 'package:yournotalone/therapy/therapy_screen.dart';

final _now = DateTime(2026, 9, 14, 12);
final _start = _now.add(const Duration(hours: 2));

TherapyRequest _request({
  String id = 'r1',
  String status = 'confirmed',
  bool free = false,
  String payment = 'unpaid',
  String? summary,
  String? closeReason,
}) {
  final draft = status == 'awaiting_payment';
  final matched = !draft && status != 'pending';
  return TherapyRequest(
    id: id,
    topic: 'Anxiety & stress',
    availability: const ['Weekends'],
    note: null,
    status: status,
    isFreeSession: free,
    scheduledAt: matched ? _start : null,
    createdAt: _now.subtract(const Duration(days: 1)),
    submittedAt: draft ? null : _now.subtract(const Duration(days: 1)),
    therapistId: matched ? 't1' : null,
    priceCents: free ? 0 : 2000,
    paymentStatus: free ? 'not_required' : payment,
    clientSummary: summary,
    closeReason: closeReason,
  );
}

const _therapist = TherapistProfile(
  id: 't1',
  fullName: 'Tess Mwangi',
  title: 'Counselling psychologist',
  specialties: ['Anxiety & stress'],
  ratingAverage: 4.5,
  ratingCount: 6,
);

class _FakeTherapy extends TherapyRepository {
  _FakeTherapy(this.requests);

  final List<TherapyRequest> requests;
  final rated = <(String, int, String?)>[];
  final cancelled = <String>[];
  var drafts = 0;

  @override
  Future<List<TherapyRequest>> fetchRequests() async => requests;

  /// A draft the way the database saves one: unpaid, unseen by the care
  /// team, and shown as the current request from then on.
  @override
  Future<TherapyRequest> requestSession({
    required String topic,
    List<String> availability = const [],
    String? note,
  }) async {
    drafts++;
    final draft = _request(id: 'draft-$drafts', status: 'awaiting_payment');
    requests.insert(0, draft);
    return draft;
  }

  @override
  Future<void> cancelRequest(String id) async {
    cancelled.add(id);
    requests.removeWhere((r) => r.id == id);
  }

  @override
  Future<Map<String, TherapistProfile>> fetchTherapists(
          Iterable<String> ids) async =>
      const {'t1': _therapist};

  @override
  Future<Map<String, int>> fetchMyRatings() async => const {};

  @override
  Future<void> rateSession(
    String requestId, {
    required int rating,
    String? comment,
  }) async =>
      rated.add((requestId, rating, comment));
}

/// A booking the database turns down, the way 0011's caps do.
class _RefusingTherapy extends _FakeTherapy {
  _RefusingTherapy(super.requests, this.error);

  final Object error;

  @override
  Future<TherapyRequest> requestSession({
    required String topic,
    List<String> availability = const [],
    String? note,
  }) async =>
      throw error;
}

/// The store side, scripted: every payment ends the same way.
class _FixedPayments extends SessionPayments {
  _FixedPayments(this.outcome, {required super.repository});

  final SessionPaymentOutcome outcome;
  final paidFor = <String>[];

  @override
  Future<SessionPaymentOutcome> pay(TherapyRequest request) async {
    paidFor.add(request.id);
    return outcome;
  }
}

class _FakeCare extends CareRepository {
  _FakeCare({
    this.requests = const [],
    this.therapists = const [],
    this.sessions = const [],
  });

  final List<AdminTherapyRequest> requests;
  final List<AdminTherapist> therapists;
  final List<TherapistSession> sessions;
  final completed = <(String, String)>[];
  final ratedClients = <(String, int, List<String>)>[];

  @override
  Future<List<AdminTherapyRequest>> listRequests() async => requests;

  @override
  Future<List<AdminTherapist>> listTherapists() async => therapists;

  @override
  Future<List<TherapistSession>> listMySessions() async => sessions;

  @override
  Future<void> completeSession(String requestId, String summary) async =>
      completed.add((requestId, summary));

  @override
  Future<void> rateClient(
    String requestId, {
    required int rating,
    String? comment,
    List<String> flags = const [],
  }) async =>
      ratedClients.add((requestId, rating, flags));
}

class _FakeKeepAlive implements CallKeepAlive {
  final started = <String>[];
  var stops = 0;

  @override
  Future<void> start({required String counterpartName}) async =>
      started.add(counterpartName);

  @override
  Future<void> stop() async => stops++;
}

Finder _button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

bool _enabled(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(_button(label).first).onPressed != null;

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

  group('join window', () {
    JoinState at(Duration offset) => sessionJoinState(
          _start.add(offset),
          scheduledAt: _start,
          durationMinutes: 50,
        );

    test('opens ten minutes before and closes half an hour after', () {
      expect(at(const Duration(minutes: -11)), JoinState.tooEarly);
      expect(at(const Duration(minutes: -10)), JoinState.open);
      expect(at(const Duration(minutes: 25)), JoinState.open);
      expect(at(const Duration(minutes: 80)), JoinState.open);
      expect(at(const Duration(minutes: 81)), JoinState.over);
    });

    test('nothing to join until a session is scheduled', () {
      expect(
        sessionJoinState(_now, scheduledAt: null, durationMinutes: 50),
        JoinState.notScheduled,
      );
      expect(_request(status: 'pending').joinStateAt(_now),
          JoinState.notScheduled);
    });
  });

  group('sessions', () {
    test('prices read as whole dollars when they are', () {
      expect(formatPrice(2000), '\$20');
      expect(formatPrice(2050), '\$20.50');
    });

    test('rows from before pricing existed still parse', () {
      final request = TherapyRequest.fromRow({
        'id': 'r',
        'topic': 'Low mood',
        'availability': ['Weekends'],
        'note': null,
        'status': 'pending',
        'is_free_session': true,
        'scheduled_at': null,
        'created_at': '2026-09-14T09:00:00Z',
      });
      expect(request.paymentStatus, 'not_required');
      expect(request.durationMinutes, 50);
      expect(request.canCancelAt(_now), isTrue);
    });

    test('a booked session can be cancelled until a day before it starts',
        () {
      final paid = _request(payment: 'paid');
      expect(paid.canCancelAt(_start.subtract(const Duration(hours: 25))),
          isTrue);
      expect(paid.canCancelAt(_start.subtract(const Duration(hours: 23))),
          isFalse);
      expect(paid.isLockedInAt(_start.subtract(const Duration(hours: 23))),
          isTrue);
      // Not matched yet: cancel any time, the care team refunds it.
      expect(_request(status: 'pending', payment: 'paid').canCancelAt(_now),
          isTrue);
      // A draft costs nothing to drop.
      final draft = _request(status: 'awaiting_payment');
      expect(draft.isCurrent, isTrue);
      expect(draft.isActive, isFalse);
      expect(draft.canCancelAt(_now), isTrue);
    });

    test('a session stays locked to the app once its call opens', () {
      final session = _request(payment: 'paid');
      expect(session.canCancelAt(_start.subtract(const Duration(minutes: 10))),
          isFalse);
      expect(session.canCancelAt(_start.add(const Duration(hours: 1))),
          isFalse);
      // A request that hasn't been matched has no start to pass.
      expect(
          _request(status: 'pending', payment: 'paid')
              .canCancelAt(_start.add(const Duration(days: 30))),
          isTrue);
    });

    test('too early says when the call opens', () {
      final message = SessionAccessException(
        'too_early',
        opensAt: DateTime(2026, 9, 14, 13, 50),
      ).message;
      expect(message, contains('13:50'));
    });
  });

  group('client therapy screen', () {
    testWidgets('a matched, unpaid session shows who, the price, and a '
        'locked call', (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request()]),
          clock: () => _start.subtract(const Duration(minutes: 5)),
        ),
      );

      expect(find.text('You\'re matched'), findsOneWidget);
      expect(find.text('Tess Mwangi'), findsOneWidget);
      expect(find.text('Pay \$20'), findsOneWidget);
      expect(_enabled(tester, 'Join session'), isFalse);
      expect(find.text('The call opens once your session is paid for.'),
          findsOneWidget);
      // The call has opened, so cancelling is the care team's call now.
      expect(find.text('Cancel session'), findsNothing);
    });

    testWidgets('a paid session opens the call ten minutes before the start',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(payment: 'paid')]),
          clock: () => _start.subtract(const Duration(minutes: 10)),
        ),
      );
      expect(find.text('Session confirmed'), findsOneWidget);
      expect(_enabled(tester, 'Join session'), isTrue);
      expect(find.text('Pay \$20'), findsNothing);
      // Paid sessions are cancelled through the care team.
      expect(find.text('Cancel session'), findsNothing);
    });

    testWidgets('the call stays shut until ten minutes before', (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(payment: 'paid')]),
          clock: () => _start.subtract(const Duration(minutes: 11)),
        ),
      );
      expect(_enabled(tester, 'Join session'), isFalse);
      expect(find.text('The call opens 10 minutes before the start.'),
          findsOneWidget);
    });

    testWidgets('a paid request waiting for a match can be cancelled',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(status: 'pending', payment: 'paid')]),
          clock: () => _now,
        ),
      );
      expect(find.text('Request received'), findsOneWidget);
      expect(find.text('\$20 — paid, receipt emailed'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);
      expect(find.text('Pay \$20'), findsNothing);
      expect(find.text('Join session'), findsNothing);
    });

    testWidgets('a session less than a day away can no longer be cancelled',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(payment: 'paid')]),
          clock: () => _start.subtract(const Duration(hours: 23)),
        ),
      );
      expect(find.text('Join session'), findsOneWidget);
      expect(find.text('Cancel session'), findsNothing);
      expect(find.textContaining('isn\'t refunded'), findsOneWidget);
    });

    testWidgets('a session more than a day away can still be cancelled',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(payment: 'paid')]),
          clock: () => _start.subtract(const Duration(hours: 25)),
        ),
      );
      expect(find.text('Cancel session'), findsOneWidget);
    });

    testWidgets('booking asks for payment up front and says what it buys',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(status: 'completed')]),
          clock: () => _now,
        ),
      );
      expect(find.text('Sessions are \$20, paid when you book'), findsOneWidget);
      expect(find.text('Pay \$20 and request a session'), findsOneWidget);
      expect(find.textContaining('up to 24 hours before'), findsWidgets);
      expect(find.textContaining('free'), findsNothing);
    });

    testWidgets('paying sends the request; backing out discards the draft',
        (tester) async {
      final repo = _FakeTherapy([]);
      final payments =
          _FixedPayments(SessionPaymentOutcome.cancelled, repository: repo);
      await _show(
        tester,
        TherapyScreen(repository: repo, payments: payments, clock: () => _now),
      );
      await tester.tap(find.text('Anxiety & stress'));
      await tester.pump();
      await tester.tap(find.text('Pay \$20 and request a session'));
      await _settle(tester);

      // The draft was saved, offered to the store, then dropped — and the
      // form is still there with the topic chosen.
      expect(payments.paidFor, ['draft-1']);
      expect(repo.cancelled, ['draft-1']);
      expect(find.text('Pay \$20 and request a session'), findsOneWidget);
      expect(find.text('Almost there'), findsNothing);
    });

    testWidgets('a payment the store took but the server hasn\'t seen keeps '
        'the draft on screen', (tester) async {
      final repo = _FakeTherapy([]);
      final payments = _FixedPayments(
          SessionPaymentOutcome.pendingVerification,
          repository: repo);
      await _show(
        tester,
        TherapyScreen(repository: repo, payments: payments, clock: () => _now),
      );
      await tester.tap(find.text('Anxiety & stress'));
      await tester.pump();
      await tester.tap(find.text('Pay \$20 and request a session'));
      await _settle(tester);

      expect(repo.cancelled, isEmpty);
      expect(find.text('Almost there'), findsOneWidget);
      expect(find.text('\$20 — pay to send your request'), findsOneWidget);
      expect(_button('Check payment'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
    });

    testWidgets('a refused booking shows the database\'s reason',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _RefusingTherapy(
            const [],
            const PostgrestException(
              message: 'You already have a session on the way. Cancel it '
                  'first if you need to change something.',
              code: 'P0001',
            ),
          ),
          clock: () => _now,
        ),
      );
      await tester.tap(find.text('Anxiety & stress'));
      await tester.pump();
      await tester.tap(find.text('Pay \$20 and request a session'));
      await _settle(tester);
      expect(
        find.text('You already have a session on the way. Cancel it first '
            'if you need to change something.'),
        findsOneWidget,
      );
      expect(find.text('Pay \$20 and request a session'), findsOneWidget);
    });

    testWidgets('a finished session shows the note and takes a rating',
        (tester) async {
      final repository = _FakeTherapy([
        _request(
          status: 'completed',
          payment: 'paid',
          summary: 'Practise the 4-7-8 breath.',
        ),
      ]);
      await _show(
        tester,
        TherapyScreen(repository: repository, clock: () => _now),
      );

      await tester.tap(find.text('Rate'));
      await _settle(tester);
      expect(find.text('Practise the 4-7-8 breath.'), findsOneWidget);

      await tester.tap(find.text('Rate this session'));
      await _settle(tester);
      expect(_enabled(tester, 'Send rating'), isFalse);

      await tester.tap(find.byTooltip('4 out of 5'));
      await tester.pump();
      await tester.tap(find.text('Send rating'));
      await _settle(tester);

      expect(repository.rated, [('r1', 4, null)]);
      expect(find.text('Thank you — that helps.'), findsOneWidget);
    });
  });

  testWidgets('a refused call says why instead of connecting', (tester) async {
    final keepAlive = _FakeKeepAlive();
    await _show(
      tester,
      CallScreen(
        counterpartName: 'Tess Mwangi',
        connect: () async =>
            throw const SessionAccessException('payment_required'),
        keepAlive: keepAlive,
      ),
    );
    expect(find.text('Couldn\'t join'), findsOneWidget);
    expect(
      find.text('This session needs to be paid for before you can join.'),
      findsOneWidget,
    );
    // Nothing to keep alive: no wakelock or service for a call that never
    // connected, and whatever was held is released on the way out.
    expect(keepAlive.started, isEmpty);
    expect(keepAlive.stops, greaterThan(0));

    // Backgrounding a screen that isn't in a call is a no-op. Delivered to
    // the screen's observer directly: the binding would also wake Supabase's
    // token refresh, which is not what's under test.
    final observer =
        tester.state(find.byType(CallScreen)) as WidgetsBindingObserver;
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Couldn\'t join'), findsOneWidget);
  });

  testWidgets('leaving the call screen releases what kept it alive',
      (tester) async {
    final keepAlive = _FakeKeepAlive();
    await _show(
      tester,
      CallScreen(
        counterpartName: 'Tess Mwangi',
        connect: () async => throw StateError('signed out'),
        keepAlive: keepAlive,
      ),
    );
    final stopsBefore = keepAlive.stops;
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(keepAlive.stops, greaterThan(stopsBefore));
  });

  group('care team', () {
    AdminTherapyRequest item(TherapyRequest request, {String name = 'Anna K'}) =>
        AdminTherapyRequest(
          request: request,
          clientId: 'c1',
          clientName: name,
          clientEmail: 'anna@example.com',
          therapistName: request.therapistId == null ? null : 'Tess Mwangi',
        );

    testWidgets('the dashboard flags long waits and unsigned-in therapists',
        (tester) async {
      final waiting = TherapyRequest(
        id: 'p1',
        topic: 'Low mood',
        availability: const [],
        note: null,
        status: 'pending',
        isFreeSession: true,
        scheduledAt: null,
        createdAt: _now.subtract(const Duration(hours: 30)),
      );
      await _show(
        tester,
        CareDashboardScreen(
          clock: () => _now,
          repository: _FakeCare(
            requests: [item(waiting), item(_request(), name: 'Ben O')],
            therapists: const [
              AdminTherapist(
                profile: _therapist,
                email: 'tess@example.com',
                hasAccount: false,
              ),
            ],
          ),
        ),
      );

      expect(find.text('To match · 1'), findsOneWidget);
      expect(find.text('Upcoming · 1'), findsOneWidget);
      expect(find.text('Waiting 30h'), findsOneWidget);
      expect(find.text('Anna K'), findsOneWidget);

      await tester.tap(find.text('Upcoming · 1'));
      await tester.pump();
      expect(find.text('Ben O'), findsOneWidget);
      expect(find.text('Unpaid'), findsOneWidget);

      await tester.tap(find.text('Therapists'));
      await _settle(tester);
      expect(find.text('Not signed in yet — tess@example.com'), findsOneWidget);
    });

    testWidgets('a therapist finishes a session with a note, rating and flag',
        (tester) async {
      final repository = _FakeCare(
        sessions: [
          TherapistSession(
            id: 's1',
            status: 'confirmed',
            topic: 'Anxiety & stress',
            availability: const [],
            scheduledAt: _start,
            durationMinutes: 50,
            paymentStatus: 'paid',
            isFreeSession: false,
            clientFirstName: 'Anna',
          ),
        ],
      );
      await _show(
        tester,
        TherapistSessionsScreen(
          repository: repository,
          clock: () => _start.add(const Duration(minutes: 45)),
        ),
      );

      expect(_enabled(tester, 'Join session'), isTrue);
      await tester.tap(find.text('Finish session'));
      await _settle(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'A note for Anna (optional)'),
        'Keep a sleep diary this week.',
      );
      await tester.tap(find.byTooltip('5 out of 5'));
      await tester.tap(find.text('Needs a follow-up'));
      await tester.pump();
      await tester.tap(_button('Finish session').last);
      await _settle(tester);

      expect(repository.completed, [('s1', 'Keep a sleep diary this week.')]);
      final (id, rating, flags) = repository.ratedClients.single;
      expect((id, rating), ('s1', 5));
      expect(flags, ['follow_up']);
    });

    testWidgets('a therapist waits for an unpaid client', (tester) async {
      await _show(
        tester,
        TherapistSessionsScreen(
          clock: () => _start,
          repository: _FakeCare(
            sessions: [
              TherapistSession(
                id: 's1',
                status: 'confirmed',
                topic: 'Anxiety & stress',
                availability: const [],
                scheduledAt: _start,
                durationMinutes: 50,
                paymentStatus: 'unpaid',
                isFreeSession: false,
                clientFirstName: 'Anna',
              ),
            ],
          ),
        ),
      );
      expect(_enabled(tester, 'Join session'), isFalse);
      expect(
        find.text('The client hasn\'t paid yet — the call opens once they do.'),
        findsOneWidget,
      );
    });
  });

  group('sessions nobody finished', () {
    // Two hours after a 50-minute session ended: the server's sweep is due.
    final later = _start.add(const Duration(hours: 3));

    test('a session the server closed reads by what happened', () {
      expect(sessionOutcomeLabel(_request(status: 'completed')), 'Completed');
      expect(
        sessionOutcomeLabel(
            _request(status: 'completed', closeReason: 'client_no_show')),
        'Missed',
      );
      expect(
        sessionOutcomeLabel(
            _request(status: 'cancelled', closeReason: 'nobody_joined')),
        'Didn\'t happen',
      );
      expect(
        sessionOutcomeLabel(
            _request(status: 'cancelled', closeReason: 'therapist_no_show')),
        'Didn\'t happen',
      );
      expect(
        sessionOutcomeLabel(_request(status: 'cancelled', closeReason: 'unpaid')),
        'Not paid',
      );
      expect(sessionOutcomeLabel(_request(status: 'cancelled')), 'Cancelled');
    });

    test('a confirmed session has elapsed once its call window closes', () {
      final session = _request(payment: 'paid');
      expect(session.hasElapsedAt(_start), isFalse);
      expect(session.hasElapsedAt(_start.add(const Duration(minutes: 80))),
          isFalse);
      expect(session.hasElapsedAt(_start.add(const Duration(minutes: 81))),
          isTrue);
      expect(_request(status: 'pending').hasElapsedAt(later), isFalse);
    });

    testWidgets('an unpaid session whose time has passed can no longer be '
        'paid for, and says it will be cancelled', (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request()]),
          clock: () => later,
        ),
      );
      expect(_button('Pay \$20'), findsNothing);
      expect(find.text('Already paid? Check again'), findsNothing);
      expect(find.textContaining('cancelled shortly'), findsOneWidget);
      expect(find.textContaining('contact us'), findsNothing);
    });

    testWidgets('a paid session whose time has passed says it closes on its '
        'own', (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(payment: 'paid')]),
          clock: () => later,
        ),
      );
      expect(find.textContaining('closes out on its own'), findsOneWidget);
      expect(find.textContaining('contact us'), findsNothing);
      expect(_enabled(tester, 'Join session'), isFalse);
    });

    testWidgets('a missed session is listed as such, with nothing to rate',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([
            _request(id: 'm1', status: 'completed', closeReason: 'client_no_show'),
            _request(id: 'n1', status: 'cancelled', closeReason: 'nobody_joined'),
          ]),
          clock: () => later,
        ),
      );
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Didn\'t happen'), findsOneWidget);
      expect(find.text('Rate'), findsNothing);
      // Both are over, so booking is open again.
      expect(find.text('Cancelled'), findsNothing);
      expect(_button('Pay \$20 and request a session'), findsOneWidget);
    });

    testWidgets('the care dashboard flags a session nobody finished',
        (tester) async {
      await _show(
        tester,
        CareDashboardScreen(
          clock: () => later,
          repository: _FakeCare(
            requests: [
              AdminTherapyRequest(
                request: _request(payment: 'paid'),
                clientId: 'c1',
                clientName: 'Anna K',
                therapistName: 'Tess Mwangi',
              ),
              AdminTherapyRequest(
                request: _request(
                    id: 'u1', status: 'cancelled', closeReason: 'unpaid'),
                clientId: 'c2',
                clientName: 'Ben O',
                therapistName: 'Tess Mwangi',
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Upcoming · 1'));
      await tester.pump();
      expect(find.textContaining('Not finished'), findsOneWidget);
      await tester.tap(find.text('Past · 1'));
      await tester.pump();
      expect(find.textContaining('Not paid'), findsOneWidget);
    });

    testWidgets('a therapist sees who turned up to a closed session',
        (tester) async {
      TherapistSession session(String id, String status, String reason) =>
          TherapistSession(
            id: id,
            status: status,
            topic: 'Anxiety & stress',
            availability: const [],
            scheduledAt: _start,
            durationMinutes: 50,
            paymentStatus: 'paid',
            isFreeSession: false,
            clientFirstName: 'Anna',
            closeReason: reason,
          );
      await _show(
        tester,
        TherapistSessionsScreen(
          repository: _FakeCare(sessions: [
            session('s1', 'completed', 'client_no_show'),
            session('s2', 'cancelled', 'nobody_joined'),
          ]),
          clock: () => later,
        ),
      );
      expect(find.text('The client didn\'t join the call.'), findsOneWidget);
      expect(find.text('Didn\'t happen'), findsOneWidget);
      expect(find.text('Cancelled'), findsNothing);
    });
  });
}
