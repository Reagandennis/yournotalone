import 'package:flutter/widgets.dart';

import '../meditation/session_clock.dart';

/// A countdown for a screen, kept by the wall clock.
///
/// A timer that takes a second off each time it fires stands still while
/// the phone is locked, because the app's timers stop with it: a
/// fifteen-minute break could run for an hour, and an exercise would pick
/// up where it was when the screen went dark. This reads the time through
/// a [SessionClock] instead, checks again the moment the app is back, and
/// finishes the countdown if its end went by while the app was away.
///
/// The screen rebuilds as the clock ticks; it reads [countdown],
/// [secondsLeft] or [secondsGone] in `build`.
mixin WallClockCountdown<T extends StatefulWidget> on State<T> {
  SessionClock? _countdown;
  AppLifecycleListener? _lifecycle;

  /// The countdown that's running, paused or just finished; null before
  /// the first start and after [stopCountdown].
  SessionClock? get countdown => _countdown;

  /// Seconds still to go, rounded up as a countdown shows them: the full
  /// length straight after the start, and 0 only once it's over.
  int get secondsLeft {
    final left = _countdown?.remaining ?? Duration.zero;
    return (left.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
  }

  /// Whole seconds gone since the start, not counting pauses.
  int get secondsGone => _countdown?.elapsed.inSeconds ?? 0;

  /// Starts a fresh countdown of [length], dropping any earlier one.
  /// [onDone] runs once, when the time is up; `late` means it ran out a
  /// while ago, with the app away, so a sound now would ring for nothing.
  void startCountdown(
    Duration length, {
    required void Function({required bool late}) onDone,
  }) {
    stopCountdown();
    final countdown = SessionClock(
      length,
      onDone: ({required late}) {
        if (mounted) onDone(late: late);
      },
    )..addListener(_tick);
    _countdown = countdown;
    _lifecycle ??= AppLifecycleListener(onResume: () => _countdown?.check());
    countdown.start();
  }

  /// Drops the countdown without finishing it.
  void stopCountdown() {
    final countdown = _countdown;
    _countdown = null;
    countdown
      ?..removeListener(_tick)
      ..dispose();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    stopCountdown();
    _lifecycle?.dispose();
    super.dispose();
  }
}
