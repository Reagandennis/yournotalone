import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../practice/practice_repository.dart';
import 'health_data.dart';

/// Where the health connection stands on this phone.
enum HealthStatus {
  /// Not checked yet.
  unknown,

  /// No Apple Health or Health Connect here (an iPad, an Android phone
  /// whose Health Connect can't run).
  unavailable,

  /// Android 13 and lower: Health Connect needs installing or updating
  /// from Google Play first.
  needsInstall,

  /// Available, and the person hasn't connected it.
  notConnected,

  /// Connected: the app reads and writes what it said it would.
  connected,
}

/// Apple Health on iPhone, Health Connect on Android.
///
/// **Privacy.** What's read here stays in memory on the phone. It is never
/// sent to Supabase, Sentry or anyone else, and never written to the app's
/// own storage: it's read again from the platform each time it's needed.
/// The only thing that leaves this class is last night's sleep length, for
/// the home-screen widget, and only while [showSleepOnWidget] is on. Errors
/// are logged by their type alone, never with values, because the app's
/// debug lines go to Sentry in release builds. (For the same reason, don't
/// call the plugin's `getHealthDataByUUID`: it prints the data it reads.)
///
/// **Consent.** Nothing is read until someone taps Connect on the health
/// screen, which says what is read and written and why, and then grants
/// it in the system's own sheet. Disconnecting stops every read and write
/// at once.
class HealthService extends ChangeNotifier {
  HealthService._();

  static final instance = HealthService._();

  /// Widget tests have no platform to talk to.
  static final bool _silent = Platform.environment.containsKey('FLUTTER_TEST');

  // Per account, through LocalData (the "health." prefix).
  static const _connectedKey = 'health.connected';
  static const _consentAtKey = 'health.consent_at';
  static const _widgetSleepKey = 'health.widget_sleep';

  final _health = Health();
  bool _configured = false;

  HealthStatus _status = HealthStatus.unknown;
  HealthStatus get status => _status;
  bool get connected => _status == HealthStatus.connected;

  HealthHistory _history = HealthHistory.empty;

  /// The last 30 days, in memory only.
  HealthHistory get history => _history;
  DateTime? _readAt;

  bool _showSleepOnWidget = true;
  bool get showSleepOnWidget => _showSleepOnWidget;

  /// Whether this phone can record mindful minutes: always with Apple
  /// Health; on Android only where Health Connect has mindfulness sessions
  /// (Android 16, or 14–15 with a recent system update).
  bool _canWriteMindful = false;
  bool get canWriteMindful => _canWriteMindful;

  /// "Apple Health" or "Health Connect": product names, the same in every
  /// language.
  static String get platformName =>
      Platform.isIOS ? 'Apple Health' : 'Health Connect';

  List<HealthDataType> get _readTypes => Platform.isIOS
      ? const [
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE_VARIABILITY_SDNN,
          HealthDataType.RESTING_HEART_RATE,
        ]
      : const [
          HealthDataType.SLEEP_SESSION,
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_LIGHT,
          HealthDataType.SLEEP_REM,
          HealthDataType.STEPS,
          HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
          HealthDataType.RESTING_HEART_RATE,
        ];

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  void _set(HealthStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  /// Works out the status and, when connected, reads the latest. Called at
  /// launch and whenever the app comes back. Never throws.
  Future<void> load() async {
    if (_silent) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _showSleepOnWidget = prefs.getBool(_widgetSleepKey) ?? true;
      if (!Platform.isIOS && !Platform.isAndroid) {
        _set(HealthStatus.unavailable);
        return;
      }
      await _configure();
      if (Platform.isAndroid) {
        final sdk = await _health.getHealthConnectSdkStatus();
        if (sdk == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          _set(HealthStatus.needsInstall);
          return;
        }
        if (sdk != HealthConnectSdkStatus.sdkAvailable) {
          _set(HealthStatus.unavailable);
          return;
        }
        _canWriteMindful = await _health.isMindfulnessSessionAvailable();
      } else {
        _canWriteMindful = true;
      }
      if (prefs.getBool(_connectedKey) ?? false) {
        // On Android, permissions can be taken away in Health Connect's
        // own settings; then the app is no longer connected.
        if (Platform.isAndroid &&
            await _health.hasPermissions(
                  _readTypes,
                  permissions: [for (final _ in _readTypes) HealthDataAccess.READ],
                ) ==
                false) {
          final any = await _anyReadGranted();
          if (!any) {
            await prefs.setBool(_connectedKey, false);
            _history = HealthHistory.empty;
            _set(HealthStatus.notConnected);
            return;
          }
        }
        _set(HealthStatus.connected);
        await refresh();
      } else {
        _set(HealthStatus.notConnected);
      }
    } catch (e) {
      debugPrint('Health status unavailable: ${e.runtimeType}');
      _set(HealthStatus.unavailable);
    }
  }

  /// Someone may allow sleep but not heart data: still connected.
  Future<bool> _anyReadGranted() async {
    for (final type in _readTypes) {
      if (await _health.hasPermissions(
            [type],
            permissions: const [HealthDataAccess.READ],
          ) ==
          true) {
        return true;
      }
    }
    return false;
  }

  /// Opens Google Play on Health Connect (Android 13 and lower).
  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('Health Connect install failed: ${e.runtimeType}');
    }
  }

  /// Asks the system for access, after the person has read what it's for
  /// and tapped Connect. Returns whether they're now connected.
  Future<bool> connect() async {
    if (_silent) return false;
    try {
      await _configure();
      final types = [..._readTypes, if (_canWriteMindful) HealthDataType.MINDFULNESS];
      final access = [
        for (final _ in _readTypes) HealthDataAccess.READ,
        if (_canWriteMindful) HealthDataAccess.WRITE,
      ];
      final granted = await _health.requestAuthorization(types, permissions: access);
      // HealthKit never says what was allowed to be read (so an app can't
      // infer what someone has), only that the sheet was handled.
      if (!granted) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_connectedKey, true);
      // When consent was given, for the record GDPR asks controllers to
      // keep. It stays on the phone with everything else.
      await prefs.setString(_consentAtKey, DateTime.now().toUtc().toIso8601String());
      Sentry.metrics.count('health.connected', 1, attributes: {
        'platform': SentryAttribute.string(Platform.operatingSystem),
      });
      _set(HealthStatus.connected);
      await refresh(force: true);
      return true;
    } catch (e) {
      debugPrint('Health connect failed: ${e.runtimeType}');
      return false;
    }
  }

  /// Stops every read and write and forgets what was read. On Android the
  /// permissions are handed back to Health Connect too; HealthKit has no
  /// such call, so the health screen points to Settings → Health.
  Future<void> disconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_connectedKey, false);
      await prefs.remove(_consentAtKey);
    } catch (_) {}
    _history = HealthHistory.empty;
    _readAt = null;
    _set(HealthStatus.notConnected);
    Sentry.metrics.count('health.disconnected', 1);
    if (_silent || !Platform.isAndroid) return;
    try {
      await _health.revokePermissions();
    } catch (e) {
      debugPrint('Health Connect revoke failed: ${e.runtimeType}');
    }
  }

  /// Someone else signed in on this phone: nothing of the last person's
  /// health stays in memory, and their connection is looked up afresh.
  void signedOut() {
    _history = HealthHistory.empty;
    _readAt = null;
    _status = HealthStatus.unknown;
    notifyListeners();
  }

  Future<void> setShowSleepOnWidget(bool on) async {
    _showSleepOnWidget = on;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_widgetSleepKey, on);
    } catch (_) {}
  }

  // Health Connect gives 30 days before the permission was granted without
  // the separate history permission, which the app doesn't ask for.
  static const _readDays = 30;
  static const _staleAfter = Duration(minutes: 15);

  /// Reads the last 30 days into memory, unless that was done in the
  /// last quarter of an hour. Never throws: a type that fails is just
  /// missing from the days.
  Future<void> refresh({bool force = false}) async {
    if (_silent || !connected) return;
    final readAt = _readAt;
    if (!force && readAt != null && DateTime.now().difference(readAt) < _staleAfter) {
      return;
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - _readDays, 18);
    try {
      final sleep = await _readSleep(start, now);
      final steps = await _readSteps(now);
      final hrv = await _dailyAverage(
        Platform.isIOS
            ? HealthDataType.HEART_RATE_VARIABILITY_SDNN
            : HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
        start,
        now,
      );
      final rhr = await _dailyAverage(HealthDataType.RESTING_HEART_RATE, start, now);
      final keys = {...sleep.keys, ...steps.keys, ...hrv.keys, ...rhr.keys};
      _history = HealthHistory({
        for (final key in keys)
          key: DailyHealth(
            day: DateTime.parse(key),
            sleepMinutes: sleep[key]?.minutes,
            bedtime: sleep[key]?.bedtime,
            steps: steps[key],
            hrv: hrv[key],
            restingHeartRate: rhr[key],
          ),
      });
      _readAt = now;
      notifyListeners();
    } catch (e) {
      debugPrint('Health read failed: ${e.runtimeType}');
    }
  }

  Future<Map<String, ({int minutes, DateTime bedtime})>> _readSleep(
    DateTime start,
    DateTime end,
  ) async {
    final types = _readTypes
        .where((t) => t.name.startsWith('SLEEP_'))
        .toList();
    try {
      final points = await _health.getHealthDataFromTypes(
        types: types,
        startTime: start,
        endTime: end,
      );
      return nightsFrom([
        for (final p in points)
          SleepSample(
            p.dateFrom.toLocal(),
            p.dateTo.toLocal(),
            asleep: p.type != HealthDataType.SLEEP_SESSION,
            session: p.type == HealthDataType.SLEEP_SESSION,
          ),
      ]);
    } catch (e) {
      debugPrint('Health sleep read failed: ${e.runtimeType}');
      return const {};
    }
  }

  Future<Map<String, int>> _readSteps(DateTime now) async {
    final out = <String, int>{};
    for (var back = 0; back < _readDays; back++) {
      final day = DateTime(now.year, now.month, now.day - back);
      final next = DateTime(day.year, day.month, day.day + 1);
      try {
        final steps = await _health.getTotalStepsInInterval(
          day,
          next.isAfter(now) ? now : next,
        );
        // A day with no steps at all is a day with no tracker, not a day
        // spent still.
        if (steps > 0) out[PracticeRepository.dateKey(day)] = steps;
      } catch (e) {
        debugPrint('Health steps read failed: ${e.runtimeType}');
        break;
      }
    }
    return out;
  }

  Future<Map<String, double>> _dailyAverage(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
      final byDay = <String, List<double>>{};
      for (final p in points) {
        final value = p.value;
        if (value is! NumericHealthValue) continue;
        byDay
            .putIfAbsent(PracticeRepository.dateKey(p.dateTo.toLocal()), () => [])
            .add(value.numericValue.toDouble());
      }
      return {
        for (final MapEntry(:key, :value) in byDay.entries)
          key: value.reduce((a, b) => a + b) / value.length,
      };
    } catch (e) {
      debugPrint('Health ${type.name} read failed: ${e.runtimeType}');
      return const {};
    }
  }

  /// Saves a finished meditation or breathing session as mindful minutes.
  /// Sounds don't count: playing rain while working isn't mindfulness.
  /// Never throws, and does nothing unless connected.
  Future<void> recordMindful(PracticeKind kind, double minutes, {DateTime? endedAt}) async {
    if (_silent || !connected || !_canWriteMindful) return;
    if (kind == PracticeKind.sound || minutes < 1) return;
    final end = endedAt ?? DateTime.now();
    final start = end.subtract(Duration(seconds: (minutes * 60).round()));
    try {
      await _health.writeMindfulnessSession(
        startTime: start,
        endTime: end,
        sessionType: kind == PracticeKind.breathing
            ? MindfulnessSessionType.BREATHING
            : MindfulnessSessionType.MEDITATION,
      );
      Sentry.metrics.count('health.mindful_written', 1);
    } catch (e) {
      debugPrint('Mindful minutes not saved: ${e.runtimeType}');
    }
  }
}
