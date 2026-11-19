import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/cbt/worry_time_screen.dart';
import 'package:yournotalone/sleep/awake_screen.dart';
import 'package:yournotalone/sleep/sleep_content.dart';
import 'package:yournotalone/stress/muscle_relaxation_screen.dart';
import 'package:yournotalone/stress/sigh_screen.dart';
import 'package:yournotalone/toolkit/guided_exercise.dart';

// On a locked phone the app's timers stop, but the wall clock doesn't.
// These tests run on a clock that pump() moves as usual, plus [_away]:
// time that passes with no timer firing at all, as under the lock screen.

var _away = Duration.zero;

Future<void> _onLockableClock(Future<void> Function() body) {
  final pumped = clock;
  _away = Duration.zero;
  return withClock(Clock(() => pumped.now().add(_away)), body);
}

/// The phone locked for [length], then unlocked: the app goes to the
/// background, the clock moves on with no timer running, and the app
/// comes back.
Future<void> _lockFor(WidgetTester tester, Duration length) async {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  _away += length;
  for (final state in const [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

Widget _wrap(Widget screen) =>
    MaterialApp(theme: buildAppTheme(), home: screen);

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

void main() {
  // No Supabase here: these screens don't need it, and its sign-in
  // refresh would start a timer of its own each time the app comes back.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the 3am break counts the time the phone was locked', (
    tester,
  ) async {
    await _onLockableClock(() async {
      await tester.pumpWidget(_wrap(const AwakeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(_button('Yes — I\'ve been awake a while'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Start a 15-minute break'));
      await tester.pump();
      expect(find.text('15:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('14:59'), findsOneWidget);

      await _lockFor(tester, const Duration(minutes: 5));
      expect(find.text('09:59'), findsOneWidget);

      // The end goes by under the lock screen: back to step three.
      await _lockFor(tester, const Duration(minutes: 20));
      expect(
        find.text('Back to bed when sleepy — not when the clock says'),
        findsOneWidget,
      );
      expect(find.text('00:00'), findsNothing);
    });
  });

  testWidgets('the worry window closes if it ran out while locked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'cbt.worries': '[{"text":"The rent","outcome":null}]',
    });
    await _onLockableClock(() async {
      await tester.pumpWidget(_wrap(const WorryTimeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(_button('Open window'));
      await tester.pump();
      expect(find.text('15:00'), findsOneWidget);

      await _lockFor(tester, const Duration(minutes: 16));
      expect(find.textContaining('Time\'s up'), findsOneWidget);
      expect(find.text('Open window'), findsOneWidget);
    });
  });

  testWidgets('the sigh picks up where the breathing is, not where it was', (
    tester,
  ) async {
    await _onLockableClock(() async {
      await tester.pumpWidget(_wrap(const SighScreen(rounds: 3)));
      await tester.pumpAndSettle();
      await tester.tap(_button('Start'));
      await tester.pump();
      expect(find.text('Round 1 of 3'), findsOneWidget);
      expect(find.text('Breathe in'), findsOneWidget);

      // Each round is 2 + 1 + 6 seconds: 12 seconds in is the second
      // round's long breath out, with 6 of it left.
      await _lockFor(tester, const Duration(seconds: 12));
      expect(find.text('Round 2 of 3'), findsOneWidget);
      expect(find.text('Long breath out'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      await _lockFor(tester, const Duration(minutes: 1));
      expect(find.text('That\'s the round'), findsOneWidget);
      expect(find.text('Another round'), findsOneWidget);
    });
  });

  testWidgets('tense and release keeps time through the lock screen', (
    tester,
  ) async {
    await _onLockableClock(() async {
      await tester.pumpWidget(
        _wrap(
          const MuscleRelaxationScreen(tenseSeconds: 5, releaseSeconds: 10),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(_button('Begin'));
      await tester.pump();
      expect(find.text('Hands'), findsOneWidget);
      expect(find.text('Tense'), findsOneWidget);

      // 15 seconds a group: 22 in is the arms, letting go, 8 seconds left.
      await _lockFor(tester, const Duration(seconds: 22));
      expect(find.text('Arms'), findsOneWidget);
      expect(find.text('Release'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      await _lockFor(tester, const Duration(minutes: 10));
      expect(find.text('Let it all stay loose'), findsOneWidget);
      expect(find.text('Go again'), findsOneWidget);
    });
  });

  testWidgets('a step timer ends while locked, pauses, and goes again', (
    tester,
  ) async {
    const exercise = GuidedExercise(
      id: 'tool-test',
      title: 'Settle',
      blurb: 'One timed step.',
      minutes: 2,
      icon: Icons.spa_rounded,
      accent: sleepAccent,
      steps: [GuidedStep(title: 'Breathe', text: 'Slowly.', timerSeconds: 60)],
    );
    await _onLockableClock(() async {
      await tester.pumpWidget(
        _wrap(const GuidedExerciseScreen(exercise: exercise)),
      );
      await tester.tap(find.text('Start timer'));
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('0:50'), findsOneWidget);

      // Paused, time away doesn't count.
      await tester.tap(find.text('Pause'));
      await tester.pump();
      await _lockFor(tester, const Duration(minutes: 5));
      expect(find.text('0:50'), findsOneWidget);

      // Running, it does, and an end that went by while locked is over
      // (with no chime for it).
      await tester.tap(find.text('Start timer'));
      await tester.pump();
      await _lockFor(tester, const Duration(minutes: 2));
      expect(find.text('Time\'s up'), findsOneWidget);

      await tester.tap(find.text('Go again'));
      await tester.pump();
      expect(find.text('1:00'), findsOneWidget);
      await tester.tap(find.text('Pause'));
      await tester.pump();
    });
  });
}
