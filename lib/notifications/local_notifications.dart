import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// The one notifications plugin the app shares — daily reminders and therapy
/// sessions alike — so a tap is handled the same way whichever notification
/// it came from. Safe to initialise from a background isolate too.
abstract final class LocalNotifications {
  static final plugin = FlutterLocalNotificationsPlugin();

  /// Widget tests have no plugin to talk to.
  static final bool silent = Platform.environment.containsKey('FLUTTER_TEST');

  /// Called with the payload of a notification tapped while the app runs.
  static void Function(String payload)? onOpen;

  static Future<void>? _ready;
  static String? _launchPayload;

  static Future<void> ensureInitialized() {
    if (silent) return Future.value();
    return _ready ??= _initialize();
  }

  static Future<void> _initialize() async {
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone lookup failed, using UTC: $e');
    }
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onOpen?.call(payload);
      },
    );
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _launchPayload = launch?.notificationResponse?.payload;
    }
  }

  /// The payload of the notification that launched the app — handed out
  /// once, to whoever shows the first screen.
  static String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }
}
