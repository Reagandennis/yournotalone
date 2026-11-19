import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

/// A meditation's running time, kept by the wall clock.
///
/// An animation only moves while the screen draws frames, and a locked
/// phone draws none, so a session timed by one stood still under the lock
/// screen: no new guidance, no closing chime, and a sudden "complete" on
/// unlocking. This counts real time instead, and checks it with a timer,
/// which keeps running while the app does — the case whenever something
/// plays.
///
/// It reads the time through `package:clock`, so widget tests can wind it.
class SessionClock extends ChangeNotifier {
  SessionClock(this.length, {required this.onDone});

  final Duration length;

  /// Called once, when the time is up. [late] means it ran out a while
  /// ago — the app was asleep — so a chime now would ring for nothing.
  final void Function({required bool late}) onDone;

  /// How often the time is checked; listeners hear each check.
  static const tick = Duration(milliseconds: 250);

  /// How long after the end the finish still counts as on time.
  static const _onTime = Duration(seconds: 5);

  Duration _before = Duration.zero;
  DateTime? _since;
  Timer? _timer;
  bool _done = false;

  bool get running => _since != null;
  bool get done => _done;

  Duration get _raw =>
      _before +
      (_since == null ? Duration.zero : clock.now().difference(_since!));

  Duration get elapsed => _raw > length ? length : _raw;

  Duration get remaining => length - elapsed;

  /// 0 to 1.
  double get progress => length <= Duration.zero
      ? 1
      : elapsed.inMicroseconds / length.inMicroseconds;

  void start() {
    if (running || _done) return;
    _since = clock.now();
    _timer = Timer.periodic(tick, (_) => _check());
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _before = _raw;
    _since = null;
    _timer?.cancel();
    _timer = null;
    _check();
    notifyListeners();
  }

  /// Checks the time now, e.g. when the app comes back to the screen.
  void check() => _check();

  void _check() {
    if (_done) return;
    final raw = _raw;
    if (raw >= length) {
      _done = true;
      _before = length;
      _since = null;
      _timer?.cancel();
      _timer = null;
      notifyListeners();
      onDone(late: raw - length > _onTime);
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
