import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/meditation/session_clock.dart';

void main() {
  // testWidgets runs in fake time: pump() moves both the clock and timers.
  testWidgets('counts real time, and stops counting while paused', (
    tester,
  ) async {
    final ends = <bool>[];
    final session = SessionClock(
      const Duration(minutes: 5),
      onDone: ({required late}) => ends.add(late),
    );
    addTearDown(session.dispose);

    expect(session.running, isFalse);
    session.start();
    await tester.pump(const Duration(minutes: 1));
    expect(session.elapsed, const Duration(minutes: 1));
    expect(session.progress, closeTo(0.2, 1e-9));

    session.pause();
    await tester.pump(const Duration(minutes: 3));
    expect(session.elapsed, const Duration(minutes: 1));
    expect(session.remaining, const Duration(minutes: 4));

    session.start();
    await tester.pump(const Duration(minutes: 3, seconds: 59));
    expect(ends, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(ends, [false]);
    expect(session.done, isTrue);
    expect(session.running, isFalse);
    expect(session.progress, 1);

    // Finished once, for good.
    session.start();
    await tester.pump(const Duration(minutes: 1));
    expect(ends, [false]);
  });

  testWidgets('time that passed asleep counts, and a late end says so', (
    tester,
  ) async {
    final ends = <bool>[];
    var now = DateTime(2026, 11, 19, 7);
    await withClock(Clock(() => now), () async {
      final session = SessionClock(
        const Duration(minutes: 5),
        onDone: ({required late}) => ends.add(late),
      );
      session.start();
      // The app slept through the end: its timer never ran, the wall
      // clock did.
      now = now.add(const Duration(minutes: 9));
      expect(session.elapsed, const Duration(minutes: 5));
      session.check();
      expect(ends, [true]);
      session.dispose();
    });
  });

  testWidgets('listeners hear the time move', (tester) async {
    final session = SessionClock(
      const Duration(minutes: 1),
      onDone: ({required late}) {},
    );
    addTearDown(session.dispose);
    var heard = 0;
    session.addListener(() => heard++);
    session.start();
    await tester.pump(const Duration(seconds: 2));
    expect(heard, greaterThanOrEqualTo(8));
    session.pause();
  });
}
