import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/widgets.dart';

/// Whether the phone's battery saver (Low Power Mode on an iPhone) is on,
/// so backgrounds can hold still while it is.
///
/// Neither platform tells an app when the saver is switched, so it's
/// checked when something starts listening, when the app comes back to
/// the front, when the phone is plugged in or out (Android turns the saver
/// off on charge), and once a minute while anything is listening. A phone
/// that can't say counts as off.
class BatterySaver extends ChangeNotifier with WidgetsBindingObserver {
  BatterySaver._(this._probe, this._changes);

  /// Replaceable so tests can switch the saver on and off.
  static BatterySaver instance = BatterySaver._(
    () => Battery().isInBatterySaveMode,
    () => Battery().onBatteryStateChanged,
  );

  @visibleForTesting
  factory BatterySaver.forTest({
    required Future<bool> Function() probe,
    Stream<Object?> Function()? changes,
  }) => BatterySaver._(probe, changes ?? () => const Stream.empty());

  static const recheckEvery = Duration(minutes: 1);

  final Future<bool> Function() _probe;
  final Stream<Object?> Function() _changes;

  bool _on = false;
  bool _started = false;

  /// False once the phone has failed to answer: no point asking again.
  bool _supported = true;
  Timer? _timer;
  StreamSubscription<Object?>? _sub;

  bool get on => _on;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
      unawaited(refresh());
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) _stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// Asks the phone again. Never throws.
  Future<void> refresh() async {
    if (!_supported) return;
    bool on;
    try {
      on = await _probe();
    } catch (e) {
      // No plugin (tests, desktop) or a phone that won't say.
      debugPrint('Battery saver state unavailable: $e');
      _supported = false;
      _stop();
      return;
    }
    // The timer and the charge listener only once the phone has answered,
    // and only while a scene is listening.
    if (hasListeners) {
      _timer ??= Timer.periodic(recheckEvery, (_) => unawaited(refresh()));
      _sub ??= _changes().listen(
        (_) => unawaited(refresh()),
        onError: (Object e) => debugPrint('Battery changes unavailable: $e'),
      );
    }
    if (on != _on) {
      _on = on;
      notifyListeners();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    unawaited(_sub?.cancel());
    _sub = null;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }
}
