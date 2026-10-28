import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/rhythm/rhythm.dart';
import 'package:yournotalone/rhythm/rhythm_card.dart';
import 'package:yournotalone/rhythm/rhythm_screen.dart';

void main() {
  // A Wednesday, mid-morning.
  final now = DateTime(2026, 10, 28, 10);
  String ago(int days) =>
      PracticeRepository.dateKey(DateTime(now.year, now.month, now.day - days));
  // Monday is two days back; each earlier week starts seven before that.
  Set<String> weekOf(int weeksAgo, int count) => {
    for (var i = 0; i < count; i++) ago(2 + 7 * weeksAgo - i),
  };
  Rhythm compute(Set<String> days, {int goal = 3}) =>
      Rhythm.compute(days, goal: goal, now: now);

  test('the fixed day is a Wednesday', () => expect(now.weekday, 3));

  group('the maths', () {
    test('nothing yet is a fresh start, not a zero', () {
      final r = compute({});
      expect(r.isEmpty, isTrue);
      expect(r.progress, 0);
      expect(rhythmHeadline(r), 'A new week, a new sunrise');
      expect(rhythmDetail(r), contains('Any small step counts'));
    });

    test('the sun climbs towards the weekly goal', () {
      final r = compute({ago(2), ago(1)});
      expect(r.week, [true, true, false, false, false, false, false]);
      expect(r.todayIndex, 2);
      expect(r.daysThisWeek, 2);
      expect(r.progress, closeTo(2 / 3, 1e-9));
      expect(r.goalMet, isFalse);
      expect(rhythmHeadline(r), '2 of 3 days this week');
    });

    test('a week still in progress does not break the run', () {
      final r = compute({
        ago(1),
        ...weekOf(1, 3),
        ...weekOf(2, 3),
        ...weekOf(3, 4),
      });
      expect(r.daysThisWeek, 1);
      expect(r.weeksInRhythm, 3);
      expect(rhythmDetail(r), startsWith('3-week rhythm'));
    });

    test('meeting the goal joins this week to the run, with a milestone', () {
      final r = compute({
        ...weekOf(0, 3),
        ...weekOf(1, 3),
        ...weekOf(2, 3),
        ...weekOf(3, 3),
      });
      expect(r.goalMet, isTrue);
      expect(r.weeksInRhythm, 4);
      expect(r.milestone, 'A month of looking after yourself.');
      expect(rhythmHeadline(r), r.milestone);
    });

    test('a quiet week starts a new run but nothing is lost', () {
      final r = compute({...weekOf(1, 3), ...weekOf(3, 3), ...weekOf(4, 3)});
      expect(r.weeksInRhythm, 1);
      expect(r.bestWeeks, 2);
      expect(r.totalDays, 9);
      expect(r.pastWeeks.last, 3);
      expect(r.pastWeeks[r.pastWeeks.length - 2], 0);
    });

    test('after a gap, a welcome — and a check-in ends it', () {
      final r = compute({ago(9), ago(10)});
      expect(r.daysSinceLast, 9);
      expect(r.welcomeBack, isTrue);
      expect(rhythmHeadline(r), 'Welcome back');
      expect(rhythmDetail(r), contains('2 days in total'));

      final back = r.withToday(now: now);
      expect(back.welcomeBack, isFalse);
      expect(back.showedUpToday, isTrue);
      expect(back.totalDays, 3);
    });

    test('a lower goal can be met with the same days', () {
      final r = compute({ago(2), ago(1)});
      expect(r.withGoal(2, now: now).goalMet, isTrue);
      expect(compute({ago(1)}, goal: 9).goal, 7);
    });
  });

  group('the screens', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget wrap(Widget child) =>
        MaterialApp(theme: buildAppTheme(), home: child);

    testWidgets('the card says where the week stands', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: RhythmCard(
              rhythm: Rhythm.compute({
                PracticeRepository.dateKey(DateTime.now()),
              }, goal: 3),
              onTap: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('1 of 3 days this week'), findsOneWidget);
      expect(find.text('1 day in total'), findsOneWidget);
      await tester.tap(find.byType(RhythmCard));
      expect(opened, isTrue);
    });

    testWidgets('the weekly goal can be changed and is kept', (tester) async {
      await tester.pumpWidget(
        wrap(RhythmScreen(rhythm: Rhythm.compute(const {}, goal: 3))),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('3 days a week'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, '5'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('5 days a week'), findsOneWidget);
      expect(await RhythmGoal.read(), 5);
    });

    testWidgets('the card fits a small phone with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.4),
          ),
          child: wrap(
            Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: RhythmCard(
                  rhythm: Rhythm.compute(
                    {ago(9)},
                    goal: 3,
                    now: DateTime.now(),
                  ),
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    test('the goal defaults to three days', () async {
      expect(await RhythmGoal.read(), 3);
    });

    test('the goal on the profile follows the person to a new phone', () async {
      // A fresh install: nothing on the device, the goal on the profile.
      final user = User(
        id: 'u1',
        appMetadata: const {},
        userMetadata: const {RhythmGoal.profileKey: 5},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );
      expect(await RhythmGoal.read(user), 5);
    });

    test('with no profile goal, the device copy still counts', () async {
      SharedPreferences.setMockInitialValues({'rhythm.weekly_goal': 6});
      expect(await RhythmGoal.read(), 6);
    });
  });
}
