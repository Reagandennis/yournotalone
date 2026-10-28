import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/courses/course_catalog.dart';
import 'package:yournotalone/courses/course_progress.dart';
import 'package:yournotalone/courses/course_screen.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/content_widgets.dart';
import 'package:yournotalone/discover/goals.dart';
import 'package:yournotalone/discover/saved_store.dart';
import 'package:yournotalone/home/home_shell.dart';
import 'package:yournotalone/home/home_tab.dart';
import 'package:yournotalone/home/mood_insights.dart';
import 'package:yournotalone/home/mood_insights_screen.dart';
import 'package:yournotalone/home/mood_repository.dart';
import 'package:yournotalone/practice/feeling_store.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/practice/session_close_out.dart';
import 'package:yournotalone/recovery/recovery_screen.dart';
import 'package:yournotalone/reminders/reminders_service.dart';
import 'package:yournotalone/journal/journal_hub_screen.dart';
import 'package:yournotalone/support/crisis_screen.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';

class _NoPractice extends PracticeRepository {
  @override
  Future<List<PracticeSession>> fetchRecent({int days = 120}) async => [];
}

class _Feelings extends Fake implements FeelingStore {
  final recorded = <Feeling>[];

  @override
  Future<void> record({
    required PracticeKind kind,
    required String slug,
    required Feeling feeling,
  }) async =>
      recorded.add(feeling);
}

User _user({Map<String, dynamic>? meta}) => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: meta,
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

MoodEntry _mood(DateTime day, int index) =>
    MoodEntry(date: DateTime(day.year, day.month, day.day), index: index);

PracticeSession _session(DateTime at) => PracticeSession(
      kind: PracticeKind.meditation,
      slug: 'Body scan',
      title: 'Body scan',
      minutes: 12,
      completedAt: at,
    );

FeelingRecord _feeling(Feeling f, [PracticeKind k = PracticeKind.breathing]) =>
    FeelingRecord(kind: k, slug: 'x', feeling: f, at: DateTime(2026, 10, 1));

Widget _wrap(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SavedStore.instance.reset();
    CourseStore.instance.reset();
  });

  group('feel-better check', () {
    test('needs three answers before it says anything', () {
      expect(FeelingStore.summarise([_feeling(Feeling.better)]).line, isNull);
      final line = FeelingStore.summarise([
        _feeling(Feeling.better),
        _feeling(Feeling.better),
        _feeling(Feeling.same),
      ]).line;
      expect(line, 'You felt better after 2 of your last 3 sessions.');
    });

    test('learns which kinds of practice help', () {
      final help = FeelingStore.helpByKind([
        for (var i = 0; i < 3; i++) _feeling(Feeling.better),
        for (var i = 0; i < 3; i++)
          _feeling(Feeling.worse, PracticeKind.sound),
      ]);
      expect(help[PracticeKind.breathing], 1);
      expect(help[PracticeKind.sound], -1);
      expect(help.containsKey(PracticeKind.meditation), isFalse);
    });

    test('suggestions lean towards what helps', () {
      final now = DateTime(2026, 10, 23);
      final plain = recommend(needs: {Need.anxious}, now: now, premium: true);
      final boosted = recommend(
        needs: {Need.anxious},
        now: now,
        premium: true,
        kindBoost: const {ContentKind.sound: 1},
      );
      expect(boosted.first.kind, ContentKind.sound);
      expect(plain, isNotEmpty);
    });

    test('answers are kept on the device', () async {
      await FeelingStore.instance.record(
        kind: PracticeKind.breathing,
        slug: 'Box breathing',
        feeling: Feeling.better,
      );
      final recent = await FeelingStore.instance.recent();
      expect(recent.single.feeling, Feeling.better);
      expect(recent.single.slug, 'Box breathing');
    });

    testWidgets('the close-out asks better, same or worse', (tester) async {
      final feelings = _Feelings();
      await tester.pumpWidget(_wrap(SessionCloseOut(
        title: 'Box breathing',
        accent: Pillars.blue,
        kind: PracticeKind.breathing,
        feelings: feelings,
      )));
      await tester.pump();
      expect(find.text('Compared with when you started.'), findsOneWidget);
      await tester.tap(find.text('Better'));
      await tester.pump();
      expect(feelings.recorded, [Feeling.better]);
      expect(find.text('Noted. Thank you.'), findsOneWidget);
      // One answer per session.
      await tester.tap(find.text('Worse'));
      await tester.pump();
      expect(feelings.recorded, [Feeling.better]);
    });
  });

  group('insights', () {
    final now = DateTime(2026, 10, 23);

    test('say nothing without data', () {
      expect(
        moodInsights(moods: [], sessions: [], feelings: [], now: now),
        isEmpty,
      );
    });

    test('notice better moods on practice days', () {
      final moods = [
        for (var d = 0; d < 6; d++)
          _mood(now.subtract(Duration(days: d)), d.isEven ? 4 : 1),
      ];
      final sessions = [
        for (var d = 0; d < 6; d += 2) _session(now.subtract(Duration(days: d))),
      ];
      final insights = moodInsights(
        moods: moods,
        sessions: sessions,
        feelings: [],
        now: now,
      );
      expect(
        insights.map((i) => i.title),
        contains('Your mood is higher on days you practise'),
      );
    });

    test('find the hardest day of the week', () {
      // Five weeks: Mondays awful, everything else good.
      final moods = [
        for (var d = 0; d < 35; d++)
          () {
            final day = now.subtract(Duration(days: d));
            return _mood(day, day.weekday == DateTime.monday ? 0 : 3);
          }(),
      ];
      final insights = moodInsights(
        moods: moods,
        sessions: [],
        feelings: [],
        now: now,
      );
      expect(
        insights.map((i) => i.title),
        contains('Mondays are usually your hardest days'),
      );
    });

    testWidgets('are Premium only', (tester) async {
      await tester.pumpWidget(_wrap(Builder(
        builder: (context) => TextButton(
          onPressed: () => openMoodInsights(context, source: 'test'),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Insights are part of Premium'), findsOneWidget);
    });
  });

  group('courses', () {
    test('every day points at a real item', () {
      final ids = {for (final i in contentIndex) i.id};
      for (final course in courses) {
        expect(course.days, hasLength(7), reason: course.id);
        for (final day in course.days) {
          expect(ids, contains(day.itemId), reason: course.id);
        }
      }
    });

    test('one step a day', () {
      final course = courses.first;
      final day1 = DateTime(2026, 10, 20, 21);
      final progress = CourseProgress(done: {0: day1});
      expect(progress.isOpen(course, 1, day1), isFalse);
      expect(progress.isOpen(course, 1, DateTime(2026, 10, 21, 7)), isTrue);
      expect(progress.isOpen(course, 2, DateTime(2026, 10, 25)), isFalse);
      expect(progress.nextDay(course), 1);
    });

    test('goals suggest a course', () {
      expect(courseForGoals([Need.sleep])?.id, 'sleep7');
      expect(courseForGoals([Need.stressed, Need.sleep])?.id, 'stress7');
      expect(courseForGoals([Need.low])?.id, 'anxiety7');
      expect(courseForGoals([Need.focus]), isNull);
    });

    testWidgets('starting today\'s day ticks it off', (tester) async {
      final course = courses.first; // day 1 is the free Wind-down plan
      await tester.pumpWidget(_wrap(CourseScreen(course: course)));
      await tester.pumpAndSettle();
      expect(find.text('0 of 7 days done · one new step each day'),
          findsOneWidget);

      await tester.tap(find.text(course.days.first.item.title));
      await tester.pumpAndSettle();
      expect(CourseStore.instance.of(course).done.keys, [0]);
      expect(CourseStore.instance.active, course);
    });
  });

  group('goals', () {
    test('read from the profile', () {
      final user = _user(meta: {
        goalKey: ['sleep', 'nonsense', 'urges'],
      });
      expect(userGoals(user), {Need.sleep, Need.urges});
      expect(userGoals(_user()), isEmpty);
    });

    test('go first in the need order', () {
      final order = needsInGoalOrder({Need.urges});
      expect(order.first, Need.urges);
      expect(order, hasLength(Need.values.length));
    });
  });

  group('saved', () {
    testWidgets('a heart saves to Home', (tester) async {
      final item = contentIndex.firstWhere((i) => i.title == 'Box breathing');
      await tester.pumpWidget(_wrap(ContentRow(item: item, source: 'test')));
      await tester.tap(find.byTooltip('Save'));
      await tester.pump();
      expect(SavedStore.instance.items, [item]);
      expect(find.byTooltip('Remove from saved'), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance())
            .getStringList('discover.saved'),
        [item.id],
      );
    });
  });

  group('home', () {
    Widget home({Future<List<TherapyRequest>> Function()? therapy}) => _wrap(
          HomeTab(practice: _NoPractice(), therapyRequests: therapy),
        );

    testWidgets('help is one tap away', (tester) async {
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Need help now?'));
      await tester.pumpAndSettle();
      expect(find.byType(CrisisScreen), findsOneWidget);
    });

    testWidgets('saved items get their own row', (tester) async {
      final item = contentIndex.firstWhere((i) => i.title == 'Box breathing');
      await SavedStore.instance.toggle(item);
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Saved'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets('a course in progress shows on Home', (tester) async {
      await CourseStore.instance.completeDay(courses[2], 0);
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(courses[2].title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(courses[2].title), findsOneWidget);
    });

    testWidgets('a booked session offers a note to prepare',
        (tester) async {
      final at = DateTime.now().add(const Duration(days: 2));
      await tester.pumpWidget(home(
        therapy: () async => [
          TherapyRequest(
            id: 'r1',
            topic: 'Low mood',
            availability: const [],
            note: null,
            status: 'confirmed',
            isFreeSession: false,
            scheduledAt: at,
            createdAt: DateTime(2026, 10, 1),
            paymentStatus: 'paid',
          ),
        ],
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Before your session'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Before your session'), findsOneWidget);
    });

    testWidgets('after a session, its note and something to practise',
        (tester) async {
      await tester.pumpWidget(home(
        therapy: () async => [
          TherapyRequest(
            id: 'r2',
            topic: 'Anxiety & stress',
            availability: const [],
            note: null,
            status: 'completed',
            isFreeSession: false,
            scheduledAt: DateTime.now().subtract(const Duration(days: 2)),
            createdAt: DateTime(2026, 10, 1),
            completedAt: DateTime.now().subtract(const Duration(days: 2)),
            clientSummary: 'We talked about the week ahead.',
            paymentStatus: 'paid',
          ),
        ],
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('We talked about the week ahead.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('FROM YOUR LAST SESSION'), findsOneWidget);
      expect(find.text('Something to practise until next time'),
          findsOneWidget);
    });
  });

  group('reminders', () {
    testWidgets('a tapped reminder opens what it is about', (tester) async {
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        navigatorKey: key,
        home: const Scaffold(body: Text('home')),
      ));

      openReminderTarget(key.currentState!, ReminderKind.pledge.name);
      await tester.pumpAndSettle();
      expect(find.byType(RecoveryScreen), findsOneWidget);

      openReminderTarget(key.currentState!, ReminderKind.journal.name);
      await tester.pumpAndSettle();
      expect(find.byType(JournalHubScreen), findsOneWidget);
      // It went back to the start first, rather than piling up screens.
      expect(find.byType(RecoveryScreen), findsNothing);

      openReminderTarget(key.currentState!, ReminderKind.checkin.name);
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
      expect(homeTabRequest.value, 0);
    });

    test('reminder payloads name their kind', () {
      expect('$reminderPayloadPrefix${ReminderKind.windDown.name}',
          'reminder:windDown');
    });
  });
}
