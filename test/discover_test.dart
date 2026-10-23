import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/content_tags.dart';
import 'package:yournotalone/discover/usage_store.dart';
import 'package:yournotalone/home/home_tab.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';

class _NoPractice extends PracticeRepository {
  @override
  Future<List<PracticeSession>> fetchRecent({int days = 120}) async => [];
}

TherapyRequest _request(String status, {DateTime? at}) => TherapyRequest(
      id: status,
      topic: 'Anxiety',
      availability: const [],
      note: null,
      status: status,
      isFreeSession: false,
      scheduledAt: at,
      createdAt: DateTime(2026, 10, 1),
      paymentStatus: 'paid',
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('index', () {
    test('every tag line points at a real item', () {
      final ids = {for (final item in contentIndex) item.id};
      final stale = contentTags.keys.where((k) => !ids.contains(k));
      expect(stale, isEmpty, reason: 'Renamed or removed: $stale');
    });

    test('ids are unique', () {
      final ids = [for (final item in contentIndex) item.id];
      expect(ids.toSet().length, ids.length);
    });

    test('every need has something free behind it', () {
      for (final need in Need.values) {
        expect(
          contentIndex.any((i) => i.needs.contains(need) && !i.premium),
          isTrue,
          reason: '${need.label} has nothing a free user can open',
        );
      }
    });

    test('toolkit wrappers are not listed twice', () {
      expect(
        contentIndex.where((i) => i.title == 'Midday reset').length,
        1,
      );
      expect(
        contentIndex.any((i) => i.title == 'Sleep wind-down meditation'),
        isFalse,
      );
    });

    test('the urge-surfing session stays free', () {
      final surf = contentIndex.firstWhere((i) => i.title == 'Urge surfing');
      expect(surf.premium, isFalse);
      expect(surf.needs, contains(Need.urges));
    });
  });

  group('recommend', () {
    final now = DateTime(2026, 10, 23, 20);

    test('puts free items first for free users', () {
      final picks = recommend(
        needs: {Need.sleep},
        count: 3,
        now: now,
        premium: false,
      );
      expect(picks.first.premium, isFalse);
    });

    test('is the same all day and can change the next', () {
      final morning = recommend(
        dayPart: DayPart.evening,
        count: 5,
        now: DateTime(2026, 10, 23, 8),
        premium: true,
      );
      final later = recommend(
        dayPart: DayPart.evening,
        count: 5,
        now: DateTime(2026, 10, 23, 22),
        premium: true,
      );
      expect([for (final i in later) i.id], [for (final i in morning) i.id]);
    });

    test('respects the exclusions', () {
      final first = recommend(needs: {Need.low}, now: now, premium: true);
      final rest = recommend(
        needs: {Need.low},
        now: now,
        premium: true,
        exclude: {first.first.id},
      );
      expect(rest.map((i) => i.id), isNot(contains(first.first.id)));
    });

    test('the daily pick only offers free users what they can open', () {
      for (var d = 0; d < 30; d++) {
        final pick = dailyPick(
          now: DateTime(2026, 10, 1 + d),
          premium: false,
        );
        expect(pick.premium, isFalse);
      }
    });
  });

  test('day parts follow the clock', () {
    expect(DayPart.of(DateTime(2026, 1, 1, 7)), DayPart.morning);
    expect(DayPart.of(DateTime(2026, 1, 1, 14)), DayPart.afternoon);
    expect(DayPart.of(DateTime(2026, 1, 1, 19)), DayPart.evening);
    expect(DayPart.of(DateTime(2026, 1, 1, 23)), DayPart.night);
    expect(DayPart.of(DateTime(2026, 1, 1, 3)), DayPart.night);
  });

  test('length filters leave untimed items under "any" only', () {
    expect(LengthFilter.any.matches(null), isTrue);
    expect(LengthFilter.short.matches(null), isFalse);
    expect(LengthFilter.short.matches(3), isTrue);
    expect(LengthFilter.medium.matches(10), isTrue);
    expect(LengthFilter.long.matches(15), isTrue);
  });

  test('a finished session maps back to what to continue', () {
    final item = contentForPractice(PracticeSession(
      kind: PracticeKind.meditation,
      slug: 'Urge surfing',
      title: 'Urge surfing',
      minutes: 8,
      completedAt: DateTime.now(),
    ));
    expect(item?.kind, ContentKind.recovery);
  });

  test('recent searches are newest first, without repeats', () async {
    await UsageStore.instance.recordSearch('sleep');
    await UsageStore.instance.recordSearch('panic');
    await UsageStore.instance.recordSearch('Sleep');
    expect(await UsageStore.instance.recentSearches(), ['Sleep', 'panic']);
  });

  group('home', () {
    Widget home({Future<List<TherapyRequest>> Function()? therapy}) =>
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: HomeTab(practice: _NoPractice(), therapyRequests: therapy),
          ),
        );

    testWidgets('a check-in answers with something to try', (tester) async {
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      expect(find.textContaining('More for'), findsNothing);

      await tester.tap(find.text('Low'));
      await tester.pumpAndSettle();
      expect(find.text('Something that might help'), findsOneWidget);
      expect(find.text('More for “feeling low”'), findsOneWidget);
    });

    testWidgets('shows today\'s prompt or read', (tester) async {
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      final pick = dailyPick(now: DateTime.now(), premium: false);
      expect(find.text(pick.title), findsWidgets);
    });

    testWidgets('the banner shows a booked session', (tester) async {
      final at = DateTime.now().add(const Duration(days: 3));
      await tester.pumpWidget(home(
        therapy: () async => [_request('confirmed', at: at)],
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Your session'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Your session'), findsOneWidget);
      expect(find.text('Talk to a real therapist'), findsNothing);
    });

    testWidgets('the banner says when a request is being matched',
        (tester) async {
      await tester.pumpWidget(home(
        therapy: () async => [_request('pending')],
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Finding your therapist'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Finding your therapist'), findsOneWidget);
    });

    testWidgets('quick access puts the most-used tile first',
        (tester) async {
      for (var i = 0; i < 3; i++) {
        await UsageStore.instance.recordOpen(ContentKind.sound);
      }
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Quick access'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      final sounds = tester.getTopLeft(find.text('Sounds'));
      final meditate = tester.getTopLeft(find.text('Meditate'));
      expect(sounds.dx < meditate.dx || sounds.dy < meditate.dy, isTrue);
    });
  });
}
