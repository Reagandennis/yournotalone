import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../brand.dart';
import '../courses/course_progress.dart';
import '../engagement/engagement.dart';
import '../engagement/nudge_plan.dart';
import '../l10n/l10n.dart';
import '../notifications/local_notifications.dart';

/// Marks a notification payload as a daily reminder, followed by the
/// [ReminderKind] name.
const reminderPayloadPrefix = 'reminder:';

/// The four daily nudges the app can send.
enum ReminderKind {
  checkin(
    1,
    Icons.sentiment_satisfied_alt_rounded,
    Pillars.yellow,
    TimeOfDay(hour: 9, minute: 0),
  ),
  pledge(
    2,
    Icons.healing_rounded,
    Pillars.black,
    TimeOfDay(hour: 8, minute: 0),
  ),
  journal(
    3,
    Icons.edit_note_rounded,
    Pillars.red,
    TimeOfDay(hour: 20, minute: 0),
  ),
  windDown(
    4,
    Icons.bedtime_rounded,
    Pillars.blue,
    TimeOfDay(hour: 22, minute: 0),
  );

  const ReminderKind(
    this.id,
    this.icon,
    this.accent,
    this.defaultTime,
  );

  final int id;
  final IconData icon;
  final Color accent;
  final TimeOfDay defaultTime;

  String label(AppLocalizations l10n) => switch (this) {
        checkin => l10n.remindersCheckinLabel,
        pledge => l10n.remindersPledgeLabel,
        journal => l10n.remindersJournalLabel,
        windDown => l10n.remindersWindDownLabel,
      };

  String description(AppLocalizations l10n) => switch (this) {
        checkin => l10n.remindersCheckinDescription,
        pledge => l10n.remindersPledgeDescription,
        journal => l10n.remindersJournalDescription,
        windDown => l10n.remindersWindDownDescription,
      };

  String notificationTitle(AppLocalizations l10n) => switch (this) {
        checkin => l10n.remindersCheckinTitle,
        pledge => l10n.remindersPledgeTitle,
        journal => l10n.remindersJournalTitle,
        windDown => l10n.remindersWindDownTitle,
      };

  String notificationBody(AppLocalizations l10n) => switch (this) {
        checkin => l10n.remindersCheckinBody,
        pledge => l10n.remindersPledgeBody,
        journal => l10n.remindersJournalBody,
        windDown => l10n.remindersWindDownBody,
      };
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

  tz.TZDateTime _nextInstance(TimeOfDay time) =>
      nextInstanceAfter(tz.TZDateTime.now(tz.local), time);

  /// The next [time] on the wall clock after [now], in [now]'s zone.
  @visibleForTesting
  static tz.TZDateTime nextInstanceAfter(tz.TZDateTime now, TimeOfDay time) {
    var scheduled = tz.TZDateTime(
        now.location, now.year, now.month, now.day, time.hour, time.minute);
    if (!scheduled.isAfter(now)) {
      // The same wall-clock time tomorrow. Adding 24 hours would land an
      // hour off on the day the clocks change.
      scheduled = tz.TZDateTime(now.location, now.year, now.month,
          now.day + 1, time.hour, time.minute);
    }
    return scheduled;
  }

  /// The words a reminder can carry, rotated day by day.
  List<String> _bodies(ReminderKind kind, AppLocalizations l10n) =>
      switch (kind) {
        ReminderKind.checkin => [
          l10n.remindersCheckinBody,
          l10n.remindersCheckinBodyAlt,
          l10n.remindersCheckinBodyAlt2,
        ],
        ReminderKind.pledge => [
          l10n.remindersPledgeBody,
          l10n.remindersPledgeBodyAlt,
        ],
        ReminderKind.journal => [
          l10n.remindersJournalBody,
          l10n.remindersJournalBodyAlt,
          l10n.remindersJournalBodyAlt2,
        ],
        ReminderKind.windDown => [
          l10n.remindersWindDownBody,
          l10n.remindersWindDownBodyAlt,
          l10n.remindersWindDownBodyAlt2,
        ],
      };

  NotificationDetails _details(AppLocalizations l10n) => NotificationDetails(
    android: AndroidNotificationDetails(
      'daily_reminders',
      l10n.remindersChannelName,
      channelDescription: l10n.remindersChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(),
    macOS: const DarwinNotificationDetails(),
  );

  Future<void> enable(ReminderKind kind, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(kind, 'enabled'), true);
    await prefs.setInt(_key(kind, 'hour'), time.hour);
    await prefs.setInt(_key(kind, 'minute'), time.minute);
    await refreshScheduled();
  }

  /// Every id a reminder of [kind] can be scheduled under: the repeating
  /// one from before the window, and each day of the window.
  Iterable<int> _ids(ReminderKind kind) => [
    kind.id,
    for (final offset in reminderOffsets) reminderWindowId(kind.id, offset),
  ];

  /// Takes every daily reminder off the phone without changing what's
  /// saved: on sign-out and account deletion, so nobody else is reminded of
  /// someone else's routine (and a deleted account isn't reminded at all).
  /// Never throws.
  Future<void> cancelScheduled() async {
    if (_silent) return;
    try {
      await _init();
      for (final kind in ReminderKind.values) {
        for (final id in _ids(kind)) {
          await _plugin.cancel(id: id);
        }
      }
    } catch (e) {
      debugPrint('Couldn\'t cancel reminders: $e');
    }
  }

  /// Puts every enabled reminder on the phone's schedule again, from now.
  /// Called whenever the app opens, so the two-week window (see
  /// [planReminders]) starts over for anyone still using the app and runs
  /// out for anyone who has stopped. Never throws.
  ///
  /// The holdout group (see [isEngagementHoldout]) keeps the reminders as
  /// they were before: one notification repeating every day.
  Future<void> refreshScheduled() async {
    if (_silent) return;
    try {
      await _init();
      // Written now, in the app's language at the time.
      final l10n = currentL10n();
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final holdout = userId != null && isEngagementHoldout(userId);
      final settings = <ReminderSetting>[];
      for (final kind in ReminderKind.values) {
        for (final id in _ids(kind)) {
          await _plugin.cancel(id: id);
        }
        if (!await isEnabled(kind)) continue;
        final time = await timeOf(kind);
        if (holdout) {
          await _scheduleRepeating(kind, time, l10n);
          continue;
        }
        settings.add(
          ReminderSetting(
            kindName: kind.name,
            kindId: kind.id,
            hour: time.hour,
            minute: time.minute,
            title: kind.notificationTitle(l10n),
            bodies: _bodies(kind, l10n),
            firstBody: kind == ReminderKind.checkin
                ? _courseLine(l10n)
                : null,
            // Tapping it opens what it's about (see openReminderTarget).
            payload: '$reminderPayloadPrefix${kind.name}',
          ),
        );
      }
      for (final n in planReminders(now: DateTime.now(), reminders: settings)) {
        await _plugin.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          scheduledDate: tz.TZDateTime.from(n.at, tz.local),
          notificationDetails: _details(l10n),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: n.payload,
        );
      }
    } catch (e) {
      debugPrint('Couldn\'t refresh reminders: $e');
    }
  }

  /// "Then Day 3 of “7 days to better sleep” is ready", when a course has a
  /// day open.
  String? _courseLine(AppLocalizations l10n) {
    final course = CourseStore.instance.active;
    if (course == null) return null;
    final next = CourseStore.instance.of(course).nextDay(course);
    if (next == null) return null;
    return l10n.remindersCheckinBodyCourse(next + 1, course.title);
  }

  Future<void> _scheduleRepeating(
    ReminderKind kind,
    TimeOfDay time,
    AppLocalizations l10n,
  ) => _plugin.zonedSchedule(
    id: kind.id,
    title: kind.notificationTitle(l10n),
    body: kind.notificationBody(l10n),
    scheduledDate: _nextInstance(time),
    notificationDetails: _details(l10n),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    payload: '$reminderPayloadPrefix${kind.name}',
  );

  Future<void> disable(ReminderKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(kind, 'enabled'), false);
    if (_silent) return;
    await _init();
    for (final id in _ids(kind)) {
      await _plugin.cancel(id: id);
    }
  }
}
