import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../brand.dart';
import '../notifications/local_notifications.dart';

/// Marks a notification payload as a daily reminder, followed by the
/// [ReminderKind] name.
const reminderPayloadPrefix = 'reminder:';

/// The four daily nudges the app can send.
enum ReminderKind {
  checkin(
    1,
    'Morning check-in',
    'A ten-second pulse on how you\'re doing. Opens the check-in.',
    Icons.sentiment_satisfied_alt_rounded,
    Pillars.yellow,
    TimeOfDay(hour: 9, minute: 0),
    'How are you feeling today?',
    'Take ten seconds to check in with yourself.',
  ),
  pledge(
    2,
    'Daily pledge',
    'Start the day by claiming it.',
    Icons.healing_rounded,
    Pillars.black,
    TimeOfDay(hour: 8, minute: 0),
    'A new day, on your terms',
    'Make today\'s pledge — one day at a time.',
  ),
  journal(
    3,
    'Evening pages',
    'A quiet minute for your journal. Opens your prompts.',
    Icons.edit_note_rounded,
    Pillars.red,
    TimeOfDay(hour: 20, minute: 0),
    'A quiet minute for your journal',
    'Put today into words — even a few lines count.',
  ),
  windDown(
    4,
    'Wind-down',
    'A nudge to slow down. Opens your wind-down plan.',
    Icons.bedtime_rounded,
    Pillars.blue,
    TimeOfDay(hour: 22, minute: 0),
    'Time to slow down',
    'Your wind-down plan is ready — tap to start.',
  );

  const ReminderKind(
    this.id,
    this.label,
    this.description,
    this.icon,
    this.accent,
    this.defaultTime,
    this.notificationTitle,
    this.notificationBody,
  );

  final int id;
  final String label;
  final String description;
  final IconData icon;
  final Color accent;
  final TimeOfDay defaultTime;
  final String notificationTitle;
  final String notificationBody;
}

/// Schedules the daily local notifications and remembers each reminder's
/// on/off state and time. Runs silently (state only) in widget tests.
class RemindersService {
  RemindersService._();

  static final RemindersService instance = RemindersService._();

  static final bool _silent = Platform.environment.containsKey('FLUTTER_TEST');

  FlutterLocalNotificationsPlugin get _plugin => LocalNotifications.plugin;

  Future<void> _init() => LocalNotifications.ensureInitialized();

  /// Asks the OS for notification permission; true when granted.
  Future<bool> requestPermission() async {
    if (_silent) return true;
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
              alert: true, badge: true, sound: true) ??
          true;
    }
    final macos = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) {
      return await macos.requestPermissions(
              alert: true, badge: true, sound: true) ??
          true;
    }
    return true;
  }

  // ── Preferences ────────────────────────────────────────────────

  String _key(ReminderKind kind, String suffix) =>
      'reminder_${kind.name}_$suffix';

  Future<bool> isEnabled(ReminderKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(kind, 'enabled')) ?? false;
  }

  Future<TimeOfDay> timeOf(ReminderKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_key(kind, 'hour'));
    final minute = prefs.getInt(_key(kind, 'minute'));
    if (hour == null || minute == null) return kind.defaultTime;
    return TimeOfDay(hour: hour, minute: minute);
  }

  // ── Scheduling ─────────────────────────────────────────────────

  tz.TZDateTime _nextInstance(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> enable(ReminderKind kind, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(kind, 'enabled'), true);
    await prefs.setInt(_key(kind, 'hour'), time.hour);
    await prefs.setInt(_key(kind, 'minute'), time.minute);
    if (_silent) return;
    await _init();
    await _plugin.zonedSchedule(
      id: kind.id,
      title: kind.notificationTitle,
      body: kind.notificationBody,
      scheduledDate: _nextInstance(time),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminders',
          'Daily reminders',
          channelDescription: 'Gentle daily nudges you asked for',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      // Tapping it opens what it's about (see openReminderTarget).
      payload: '$reminderPayloadPrefix${kind.name}',
    );
  }

  /// Schedules every enabled reminder again, so ones set up before
  /// reminders carried a payload open the right screen too. Never throws.
  Future<void> refreshScheduled() async {
    for (final kind in ReminderKind.values) {
      try {
        if (await isEnabled(kind)) await enable(kind, await timeOf(kind));
      } catch (e) {
        debugPrint('Couldn\'t refresh the ${kind.name} reminder: $e');
      }
    }
  }

  Future<void> disable(ReminderKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(kind, 'enabled'), false);
    if (_silent) return;
    await _init();
    await _plugin.cancel(id: kind.id);
  }
}
