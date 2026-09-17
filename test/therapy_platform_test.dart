import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/care/care_dashboard_screen.dart';
import 'package:yournotalone/care/care_repository.dart';
import 'package:yournotalone/care/therapist_sessions_screen.dart';
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
}) {
  final matched = status != 'pending';
  return TherapyRequest(
    id: id,
    topic: 'Anxiety & stress',
    availability: const ['Weekends'],
    note: null,
    status: status,
    isFreeSession: free,
    scheduledAt: matched ? _start : null,
    createdAt: _now.subtract(const Duration(days: 1)),
    therapistId: matched ? 't1' : null,
    priceCents: free ? 0 : 2000,
    paymentStatus: free ? 'not_required' : payment,
    clientSummary: summary,
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

  @override
  Future<List<TherapyRequest>> fetchRequests() async => requests;

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
  Future<void> requestSession({
    required String topic,
    List<String> availability = const [],
    String? note,
  }) async =>
      throw error;
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

    test('a paid session is cancelled through the care team', () {
      expect(_request(payment: 'paid').canCancelAt(_now), isFalse);
      expect(_request(payment: 'unpaid').canCancelAt(_now), isTrue);
    });

    test('a session is locked to the app once its call opens', () {
      final session = _request(free: true);
      final opens = _start.subtract(const Duration(minutes: 10));
      expect(session.canCancelAt(opens.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(session.canCancelAt(opens), isFalse);
      expect(session.canCancelAt(_start.add(const Duration(hours: 1))),
          isFalse);
      // A request that hasn't been matched has no start to pass.
      expect(
          _request(status: 'pending', free: true)
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

    testWidgets('a free request waiting for a match can be cancelled',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(status: 'pending', free: true)]),
          clock: () => _now,
        ),
      );
      expect(find.text('Request received'), findsOneWidget);
      expect(find.text('First session — free'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);
      expect(find.text('Join session'), findsNothing);
    });

    testWidgets('a session that has started can no longer be cancelled',
        (tester) async {
      // Cancelling after attending, before the therapist tapped Finish,
      // handed the free first session back — forever.
      final started = _start.add(const Duration(minutes: 5));
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(free: true)]),
          clock: () => started,
        ),
      );
      expect(find.text('Join session'), findsOneWidget);
      expect(find.text('Cancel session'), findsNothing);
    });

    testWidgets('a session that has not opened yet can still be cancelled',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy([_request(free: true)]),
          clock: () => _now,
        ),
      );
      expect(find.text('Cancel session'), findsOneWidget);
    });

    testWidgets('after the free session, booking shows the price',
        (tester) async {
      await _show(
        tester,
        TherapyScreen(
          repository: _FakeTherapy(
              [_request(status: 'completed', free: true)]),
          clock: () => _now,
        ),
      );
      expect(find.text('Sessions are \$20'), findsOneWidget);
      expect(find.text('Request a session'), findsOneWidget);
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
      await tester.tap(find.text('Request my free session'));
      await _settle(tester);
      expect(
        find.text('You already have a session on the way. Cancel it first '
            'if you need to change something.'),
        findsOneWidget,
      );
      expect(find.text('Request my free session'), findsOneWidget);
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
    await _show(
      tester,
      CallScreen(
        counterpartName: 'Tess Mwangi',
        connect: () async =>
            throw const SessionAccessException('payment_required'),
      ),
    );
    expect(find.text('Couldn\'t join'), findsOneWidget);
    expect(
      find.text('This session needs to be paid for before you can join.'),
      findsOneWidget,
    );
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
}
