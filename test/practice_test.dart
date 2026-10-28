import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/home_tab.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/meditation/meditation_screen.dart';
import 'package:yournotalone/practice/pending_practice.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/practice/practice_screen.dart';

class _FakePractice extends PracticeRepository {
  _FakePractice([this.sessions = const []]);

  final List<PracticeSession> sessions;
  final List<PracticeSession> logged = [];

  /// When set, every write hangs on it — a dead connection.
  Completer<void>? stuck;

  @override
  Future<void> logSession({
    required PracticeKind kind,
    required String slug,
    required String title,
    required double minutes,
  }) async {
    logged.add(
      PracticeSession(
        kind: kind,
        slug: slug,
        title: title,
        minutes: minutes,
        completedAt: DateTime.now(),
      ),
    );
    await stuck?.future;
  }

  @override
  Future<List<PracticeSession>> fetchRecent({int days = 120}) async => sessions;
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

  PracticeSession session(
    int daysAgo,
    double minutes, [
    PracticeKind kind = PracticeKind.meditation,
  ]) => PracticeSession(
    kind: kind,
    slug: 'Body scan',
    title: 'Body scan',
    minutes: minutes,
    completedAt: DateTime.now().subtract(Duration(days: daysAgo)),
  );

  // ── The maths ───────────────────────────────────────────────────

  test('a summary adds up minutes, sessions and the run of days', () {
    final summary = PracticeRepository.summarise([
      session(0, 10),
      session(1, 5),
      session(2, 12),
      session(20, 30), // outside the week
    ]);

    expect(summary.sessions, 4);
    expect(summary.totalMinutes, 57);
    expect(summary.minutesThisWeek, 27);
    expect(summary.dayStreak, 3);
    expect(summary.last?.minutes, 10);
  });

  test('a streak survives today not being practised yet', () {
    final summary = PracticeRepository.summarise([
      session(1, 5),
      session(2, 5),
    ]);
    expect(summary.dayStreak, 2);
  });

  test('a gap ends the streak', () {
    final summary = PracticeRepository.summarise([
      session(1, 5),
      session(3, 5),
    ]);
    expect(summary.dayStreak, 1);
  });

  test('nothing practised is not an error', () {
    expect(PracticeRepository.summarise(const []).isEmpty, isTrue);
    expect(PracticeSummary.empty.dayStreak, 0);
  });

  // ── Recording ───────────────────────────────────────────────────

  testWidgets('a finished meditation is written down', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);

    final practice = _FakePractice();
    final meditation = meditations.firstWhere((m) => m.minutes == 5);
    await tester.pumpWidget(
      wrap(MeditationScreen(meditation: meditation, practice: practice)),
    );
    await tester.pump();
    await tester.pump(Duration(minutes: meditation.minutes));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Session complete'), findsOneWidget);
    expect(practice.logged, hasLength(1));
    expect(practice.logged.single.title, meditation.title);
    expect(practice.logged.single.minutes, meditation.minutes.toDouble());
    expect(practice.logged.single.kind, PracticeKind.meditation);

    // And the session ends somewhere, rather than on a bare "Done".
    expect(find.text('How do you feel now?'), findsOneWidget);
    expect(find.text('Write about it'), findsOneWidget);
  });

  testWidgets('a finished meditation doesn\'t wait on the network', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 1400);
    addTearDown(tester.view.reset);

    final practice = _FakePractice()..stuck = Completer<void>();
    final meditation = meditations.firstWhere((m) => m.minutes == 5);
    await tester.pumpWidget(
      wrap(MeditationScreen(meditation: meditation, practice: practice)),
    );
    await tester.pump();
    await tester.pump(Duration(minutes: meditation.minutes));
    await tester.pump(const Duration(seconds: 1));

    // The write is still hanging, yet the session has moved on and the
    // minutes were handed over.
    expect(find.text('Session complete'), findsOneWidget);
    expect(practice.logged, hasLength(1));
    practice.stuck!.complete();
  });

  // ── Offline queue ───────────────────────────────────────────────

  group('offline queue', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    PracticeRepository repo({
      required Future<void> Function(Map<String, dynamic>) insert,
      String user = 'u1',
    }) => PracticeRepository(
      currentUserId: () => user,
      insert: insert,
      fetchRows: (_, _) async => const [],
    );

    Future<void> offline(Map<String, dynamic> _) async =>
        throw Exception('no route to host');

    test(
      'a session that can\'t be sent is kept, shown, and sent later',
      () async {
        await repo(insert: offline).logSession(
          kind: PracticeKind.breathing,
          slug: 'Box breathing',
          title: 'Box breathing',
          minutes: 3,
        );
        expect(await PendingPracticeStore().all(), hasLength(1));

        // History already includes it, so the person sees their practice.
        final shown = await repo(insert: offline).fetchRecent();
        expect(shown.single.title, 'Box breathing');
        expect(shown.single.kind, PracticeKind.breathing);

        // Back online: the same row goes up, with its own id and time.
        final sent = <Map<String, dynamic>>[];
        final online = repo(insert: (row) async => sent.add(row));
        expect(await online.flushPending(), 1);
        expect(await PendingPracticeStore().all(), isEmpty);
        expect(sent.single['user_id'], 'u1');
        expect(sent.single['minutes'], 3.0);
        expect(sent.single['id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(sent.single['completed_at'], isA<String>());
      },
    );

    test('a row the server already has counts as sent', () async {
      await repo(insert: offline).logSession(
        kind: PracticeKind.sound,
        slug: 'Rainfall',
        title: 'Rainfall',
        minutes: 4,
      );
      final dup = repo(
        insert: (_) async => throw const PostgrestException(
          message: 'duplicate key',
          code: '23505',
        ),
      );
      expect(await dup.flushPending(), 1);
      expect(await PendingPracticeStore().all(), isEmpty);
    });

    test('the queue stops at the first failure and keeps everything', () async {
      final r = repo(insert: offline);
      for (var i = 0; i < 2; i++) {
        await r.logSession(
          kind: PracticeKind.meditation,
          slug: 'm\$i',
          title: 'm\$i',
          minutes: 5,
        );
      }
      var attempts = 0;
      final still = repo(
        insert: (_) async {
          attempts++;
          throw Exception('still offline');
        },
      );
      expect(await still.flushPending(), 0);
      expect(attempts, 1);
      expect(await PendingPracticeStore().all(), hasLength(2));
    });

    test('only the signed-in person\'s sessions are sent', () async {
      await repo(insert: offline, user: 'someone-else').logSession(
        kind: PracticeKind.meditation,
        slug: 'x',
        title: 'x',
        minutes: 5,
      );
      final sent = <Map<String, dynamic>>[];
      final mine = repo(insert: (row) async => sent.add(row));
      expect(await mine.flushPending(), 0);
      expect(sent, isEmpty);
      expect(await mine.fetchRecent(), isEmpty);
      expect(await PendingPracticeStore().all(), hasLength(1));
    });
  });

  // ── The screens ─────────────────────────────────────────────────

  testWidgets('practice history shows what has been done', (tester) async {
    await tester.pumpWidget(
      wrap(
        PracticeScreen(
          repository: _FakePractice([session(0, 10), session(1, 8)]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your practice'), findsOneWidget);
    expect(find.text('2'), findsWidgets); // sessions, and the streak
    expect(find.text('18'), findsWidgets); // minutes, and this week
    expect(find.text('Today'), findsNothing); // dates live on the rows
    expect(find.text('10 min'), findsOneWidget);
  });

  testWidgets('an empty history says how to fill it', (tester) async {
    await tester.pumpWidget(wrap(PracticeScreen(repository: _FakePractice())));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('home stays quiet until there is practice to show', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(Scaffold(body: HomeTab(practice: _FakePractice()))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('minutes this week'), findsNothing);
  });

  testWidgets('home shows practice and the week\'s sunrise', (tester) async {
    await tester.pumpWidget(
      wrap(
        Scaffold(
          body: HomeTab(
            practice: _FakePractice([session(0, 10), session(1, 8)]),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    // Both days count towards the rhythm, whatever day of the week it is.
    expect(find.textContaining('2 days in total'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Your practice'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Your practice'), findsOneWidget);
    expect(find.textContaining('18 minutes this week'), findsOneWidget);
    expect(find.text('Last time: Body scan'), findsOneWidget);
    // And one tap back into it.
    expect(find.text('Continue'), findsOneWidget);
  });
}
