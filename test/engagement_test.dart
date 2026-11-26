import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/engagement/engagement.dart';
import 'package:yournotalone/engagement/nudge_plan.dart';
import 'package:yournotalone/l10n/app_localizations_en.dart';
import 'package:yournotalone/practice/practice_repository.dart';

void main() {
  final en = AppLocalizationsEn();
  // A Wednesday afternoon.
  final now = DateTime(2026, 11, 25, 15, 0);

  Set<String> daysAgo(Iterable<int> back) => {
    for (final b in back)
      PracticeRepository.dateKey(DateTime(now.year, now.month, now.day - b)),
  };

  EngagementSnapshot snap(Iterable<int> active, {int ageDays = 100}) =>
      EngagementSnapshot.compute(
        activeDays: daysAgo(active),
        accountCreated: DateTime(now.year, now.month, now.day - ageDays, 9),
        now: now,
      );

  group('stage', () {
    test('first week is newcomer whatever the activity', () {
      expect(snap([], ageDays: 0).stage, EngagementStage.newcomer);
      expect(snap([0, 1, 2], ageDays: 6).stage, EngagementStage.newcomer);
      expect(snap([0], ageDays: 6).accountAgeDays, 6);
    });

    test('weeks two to four with a recent day is forming', () {
      expect(
        snap([0, 2, 4, 6, 8, 10, 12, 14], ageDays: 20).stage,
        EngagementStage.forming,
      );
      // Never shown up until a few days ago, two weeks after signing up:
      // that's coming back.
      expect(snap([0, 2], ageDays: 20).stage, EngagementStage.returning);
      // A gap that's partly before the account existed isn't time away.
      expect(snap([0, 2], ageDays: 10).stage, EngagementStage.forming);
    });

    test('a regular past the first month is a habit', () {
      final s = snap([1, 2, 3, 5, 6, 8, 9], ageDays: 60);
      expect(s.stage, EngagementStage.habit);
      expect(s.daysSinceActive, 1);
      expect(s.usualGapDays, 1);
    });

    test('away for over twice the usual gap is slipping', () {
      // Usually every day, now four days away.
      expect(
        snap([4, 5, 6, 7, 8, 9, 10], ageDays: 60).stage,
        EngagementStage.slipping,
      );
      // Usually every three days: four days away is still normal for them.
      expect(
        snap([4, 7, 10, 13, 16], ageDays: 60).stage,
        EngagementStage.habit,
      );
    });

    test('two weeks or more away, or never, is lapsed', () {
      expect(snap([14, 15, 16], ageDays: 60).stage, EngagementStage.lapsed);
      expect(snap([], ageDays: 30).stage, EngagementStage.lapsed);
    });

    test('back within a week after two weeks away is returning', () {
      expect(snap([0, 1, 20, 21], ageDays: 60).stage, EngagementStage.returning);
      // Back for over a week: no longer returning.
      expect(
        snap([0, 2, 4, 6, 8, 30], ageDays: 60).stage,
        isNot(EngagementStage.returning),
      );
    });

    test('too little history means a usual gap of a week', () {
      expect(snap([0, 3], ageDays: 60).usualGapDays, 7);
    });
  });

  group('holdout', () {
    // The same values as the SQL rule in 0036 (computed independently:
    // int(md5(id)[:8], 16) % 100).
    test('buckets match the database rule', () {
      expect(engagementBucket('00000000-0000-0000-0000-000000000000'), 50);
      expect(engagementBucket('3f1c2a9e-7b4d-4e2a-9c1f-5d6e7f8a9b0c'), 6);
      expect(engagementBucket('a1b2c3d4-e5f6-4789-abcd-ef0123456789'), 26);
      expect(isEngagementHoldout('3f1c2a9e-7b4d-4e2a-9c1f-5d6e7f8a9b0c'), isTrue);
      expect(isEngagementHoldout('a1b2c3d4-e5f6-4789-abcd-ef0123456789'), isFalse);
    });
  });

  group('nudges', () {
    List<PlannedNotification> plan(
      EngagementSnapshot s, {
      bool enabled = true,
      bool holdout = false,
      bool hasReminders = false,
      bool lowMood = false,
      CourseStep? course,
      Suggestion? suggestion,
    }) => planNudges(
      l10n: en,
      now: now,
      snapshot: s,
      enabled: enabled,
      holdout: holdout,
      hour: 19,
      hasReminders: hasReminders,
      lowMood: lowMood,
      totalDays: 12,
      course: course,
      suggestion: suggestion,
    );

    int offsetOf(PlannedNotification n) =>
        DateTime(n.at.year, n.at.month, n.at.day)
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;

    test('none for the holdout group or when turned off', () {
      expect(plan(snap([0], ageDays: 2), holdout: true), isEmpty);
      expect(plan(snap([0], ageDays: 2), enabled: false), isEmpty);
    });

    test('a newcomer gets three in the first week, then the spaced ones', () {
      final p = plan(
        snap([0], ageDays: 1),
        course: const CourseStep(
          courseId: 'sleep7',
          courseTitle: '7 days to better sleep',
          dayNumber: 2,
        ),
      );
      expect(p.map(offsetOf), [1, 2, 4, 7, 14, 30]);
      expect(p.every((n) => n.at.hour == 19), isTrue);
      expect(p.first.title, 'Day 2 of “7 days to better sleep” is ready');
      expect(p.first.payload, 'nudge:firstWeek|course:sleep7');
      expect(p.last.title, en.nudgeLastTitle);
      // At most one a day.
      expect(p.map(offsetOf).toSet().length, p.length);
    });

    test('everyone else gets one at about twice their usual gap', () {
      final daily = plan(snap([for (var d = 0; d < 40; d++) d], ageDays: 60));
      expect(daily.map(offsetOf), [3, 7, 14, 30]);
      final weekly = plan(snap([0, 7, 14, 21, 28, 35, 42, 49], ageDays: 60));
      expect(weekly.map(offsetOf), [6, 7, 14, 30]);
    });

    test('their own reminders cover the first week', () {
      final p = plan(snap([0], ageDays: 1), hasReminders: true);
      expect(p.map(offsetOf), [7, 14, 30]);
    });

    test('very low check-ins bring support, not practice', () {
      final p = plan(snap([0], ageDays: 1), lowMood: true, hasReminders: true);
      expect(p.map(offsetOf), [2, 7]);
      expect(p.every((n) => n.payload == 'nudge:support|support'), isTrue);
      expect(p.first.title, en.nudgeSupportTitle);
    });

    test('a suggestion when there is no course', () {
      final p = plan(
        snap([0], ageDays: 1),
        suggestion: const Suggestion(
          id: 'breathing:Box breathing',
          title: 'Box breathing',
          meta: 'Breathing · 4 min',
        ),
      );
      expect(p.first.body, 'Try “Box breathing” · Breathing · 4 min');
      expect(
        parseNudgePayload(p.first.payload),
        isA<(NudgeKind, NudgeTarget)>()
            .having((r) => r.$1, 'kind', NudgeKind.firstWeek)
            .having(
              (r) => (r.$2 as ContentTarget).contentId,
              'id',
              'breathing:Box breathing',
            ),
      );
    });

    test('the nudge hour is the usual open hour, kept to daytime', () {
      expect(nudgeHour(const []), 18);
      expect(nudgeHour(const [8, 8, 9]), 9);
      expect(nudgeHour(const [23, 23, 22, 1]), 20);
      expect(nudgeHour(const [12, 13, 14]), 13);
    });

    test('payloads that are not nudges are ignored', () {
      expect(parseNudgePayload('reminder:checkin'), isNull);
      expect(parseNudgePayload('nudge:nonsense|home'), isNull);
      expect(parseNudgePayload('nudge:saved|home')?.$2, isA<HomeTarget>());
    });
  });

  group('reminders', () {
    ReminderSetting setting({String? firstBody}) => ReminderSetting(
      kindName: 'checkin',
      kindId: 1,
      hour: 9,
      minute: 0,
      title: 'How are you feeling today?',
      bodies: const ['a', 'b', 'c'],
      firstBody: firstBody,
      payload: 'reminder:checkin',
    );

    test('daily for a week, every other day, then they pause', () {
      final p = planReminders(now: now, reminders: [setting()]);
      // 09:00 today has passed, so it starts tomorrow.
      expect(
        p.map(
          (n) => DateTime(n.at.year, n.at.month, n.at.day)
              .difference(DateTime(now.year, now.month, now.day))
              .inDays,
        ),
        [1, 2, 3, 4, 5, 6, 8, 10, 12],
      );
      expect(p.map((n) => n.id).toSet().length, p.length);
      expect(p.every((n) => n.id >= 1020 && n.id <= 1092), isTrue);
    });

    test('words rotate, and the first one can be about today', () {
      final p = planReminders(
        now: now,
        reminders: [setting(firstBody: 'Then Day 3 is ready')],
      );
      expect(p.first.body, 'Then Day 3 is ready');
      expect(p.skip(1).map((n) => n.body).toSet().length, greaterThan(1));
    });

    test('later today is still today', () {
      final morning = DateTime(2026, 11, 25, 7, 0);
      final p = planReminders(now: morning, reminders: [setting()]);
      expect(p.first.at, DateTime(2026, 11, 25, 9, 0));
    });
  });
}
