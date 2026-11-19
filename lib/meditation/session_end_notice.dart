import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../notifications/local_notifications.dart';

/// The end of a silent meditation, while the phone is locked, on iPhone.
///
/// With nothing playing, iOS suspends the app soon after the screen locks,
/// so the closing chime can't ring on time; this notification rings
/// instead. It is set only while the app is in the background and nothing
/// plays, and taken back the moment either changes, so it never doubles
/// the chime. Android keeps the app running through the meditation's
/// notification, so the chime rings there itself.
///
/// It asks for nothing: without permission to notify, it simply doesn't
/// show.
abstract final class SessionEndNotice {
  static const _id = 300000201;

  static bool get supported => !LocalNotifications.silent && Platform.isIOS;

  static bool _set = false;

  static Future<void> schedule({
    required Duration inTime,
    required String title,
    required String body,
  }) async {
    if (!supported) return;
    try {
      await LocalNotifications.ensureInitialized();
      await LocalNotifications.plugin.zonedSchedule(
        id: _id,
        scheduledDate: tz.TZDateTime.from(clock.now().add(inTime), tz.local),
        notificationDetails: const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
      _set = true;
    } catch (e) {
      debugPrint('Meditation end notice unavailable: $e');
    }
  }

  static Future<void> cancel() async {
    if (!supported || !_set) return;
    _set = false;
    try {
      await LocalNotifications.plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('Meditation end notice cancel failed: $e');
    }
  }
}
