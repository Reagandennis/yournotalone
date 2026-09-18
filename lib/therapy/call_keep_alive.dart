import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps a therapy call alive while it's on screen and when it isn't.
///
/// Two things end a call that nobody meant to end. The screen times out,
/// and Android then treats the app as backgrounded. Or the person switches
/// apps. On Android 11 and later a backgrounded app loses the microphone
/// and camera unless a foreground service typed for them is running. So
/// while a call is live this holds a wakelock (the screen stays on, as in
/// any calling app) and, on Android, runs a foreground service typed
/// microphone + camera with an "In a session" notification.
///
/// iOS keeps audio going through the UIBackgroundModes audio entry in
/// Info.plist; only the wakelock applies there.
abstract class CallKeepAlive {
  Future<void> start({required String counterpartName});
  Future<void> stop();
}

class DeviceCallKeepAlive implements CallKeepAlive {
  /// Distinct from the media-playback notification of sleep sounds.
  static const _serviceId = 7001;
  static bool _initialized = false;

  static bool get _supported =>
      !kIsWeb &&
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      (Platform.isAndroid || Platform.isIOS);

  @override
  Future<void> start({required String counterpartName}) async {
    if (!_supported) return;
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Wakelock unavailable: $e');
    }
    if (!Platform.isAndroid) return;
    try {
      _init();
      if (await FlutterForegroundTask.isRunningService) return;
      final title = 'In a session with $counterpartName';
      const text = 'Tap to come back to the call.';
      // Android 14 refuses a service type whose permission isn't granted.
      // A blocked camera shouldn't cost them the microphone, so fall back.
      var result = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: [
          ForegroundServiceTypes.microphone,
          ForegroundServiceTypes.camera,
        ],
        notificationTitle: title,
        notificationText: text,
      );
      if (result is ServiceRequestFailure) {
        debugPrint('Call service (mic+camera) failed: ${result.error}');
        result = await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: [ForegroundServiceTypes.microphone],
          notificationTitle: title,
          notificationText: text,
        );
      }
      if (result is ServiceRequestFailure) {
        debugPrint('Call service (mic) failed: ${result.error}');
      }
    } catch (e) {
      debugPrint('Call service failed: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (!_supported) return;
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Wakelock release failed: $e');
    }
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Call service stop failed: $e');
    }
  }

  static void _init() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'therapy_call',
        channelName: 'Therapy session in progress',
        channelDescription:
            'Shown while you\'re in a session, so the call keeps running '
            'when you switch apps.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        showWhen: true,
        visibility: NotificationVisibility.VISIBILITY_PRIVATE,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // No background isolate: the service exists only to hold the
        // microphone and camera for the Flutter side.
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowAutoRestart: false,
        stopWithTask: true,
      ),
    );
  }
}

/// Does nothing; for tests and unsupported platforms.
class NoCallKeepAlive implements CallKeepAlive {
  const NoCallKeepAlive();

  @override
  Future<void> start({required String counterpartName}) async {}

  @override
  Future<void> stop() async {}
}
