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

  /// Bumped by every [schedule] and [cancel], so a schedule overtaken
  /// before its turn doesn't happen.
  static int _generation = 0;

  /// Schedules and cancels run one after another. A cancel that came while
  /// a schedule was still being set (the app came back to the foreground
  /// at once, say) used to find nothing set yet and return, and the
  /// schedule then went through: a notice rang after the meditation.
  static Future<void> _last = Future.value();

  static Future<void> _serially(Future<void> Function() op) {
    final next = _last.then((_) => op()).catchError((Object e) {
      debugPrint('Meditation end notice: $e');
    });
    _last = next;
    return next;
  }

  static Future<void> schedule({
    required Duration inTime,
    required String title,
    required String body,
  }) {
    if (!supported) return Future.value();
    final generation = ++_generation;
    final at = clock.now().add(inTime);
    return _serially(() async {
      // Cancelled (or scheduled again) before its turn.
      if (generation != _generation) return;
      try {
        await LocalNotifications.ensureInitialized();
        _set = true;
        await LocalNotifications.plugin.zonedSchedule(
          id: _id,
          scheduledDate: tz.TZDateTime.from(at, tz.local),
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
      } catch (e) {
        debugPrint('Meditation end notice unavailable: $e');
      }
    });
  }

  static Future<void> cancel() {
    if (!supported) return Future.value();
    _generation++;
    return _serially(() async {
      if (!_set) return;
      _set = false;
      try {
        await LocalNotifications.plugin.cancel(id: _id);
      } catch (e) {
        debugPrint('Meditation end notice cancel failed: $e');
      }
    });
  }
}
