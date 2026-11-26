import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../courses/course_catalog.dart';
import '../courses/course_progress.dart';
import '../courses/course_screen.dart';
import '../discover/content_index.dart';
import '../discover/taste_store.dart';
import '../discover/goals.dart';
import '../health/health_data.dart';
import '../health/health_service.dart';
import '../home/home_shell.dart';
import '../home/home_ui.dart';
import '../home/mood_repository.dart';
import '../home_widgets/home_widget_sync.dart';
import '../l10n/l10n.dart';
import '../notifications/local_notifications.dart';
import '../notifications/session_notifications.dart';
import '../practice/practice_repository.dart';
import '../reminders/reminders_service.dart';
import '../rhythm/rhythm.dart';
import '../support/crisis_screen.dart';
import 'engagement.dart';
import 'next_step.dart';
import 'nudge_plan.dart';

/// Runs the engagement engine each time the app opens or comes back:
///
/// 1. Notes the visit — the hour (so nudges come when this person is
///    usually around) and, once a day, a row for the retention numbers and
///    the win-back emails (`touch_app_presence`, migration 0036).
/// 2. Works out their stage (see [EngagementSnapshot]).
/// 3. Schedules the next few nudges from tomorrow, replacing the last set
///    (see [planNudges]); the reminders' own window starts over at the same
///    time (see [RemindersService.refreshScheduled]).
/// 4. Brings the home-screen widget up to date.
///
/// Everything here is best effort and never throws: a failed step leaves
/// the last schedule in place.
class EngagementService {
  EngagementService._();

  static final instance = EngagementService._();

  static final bool _silent = Platform.environment.containsKey('FLUTTER_TEST');

  // Per account, through LocalData (the "engagement." prefix).
  static const _openHoursKey = 'engagement.open_hours';
  static const _lastOpenKey = 'engagement.last_open';
  static const _presenceDayKey = 'engagement.presence_day';
  static const _nudgesKey = 'engagement.nudges_enabled';

  /// Recent opens kept for the usual hour.
  static const _hoursKept = 20;

  /// Opening the app twice in a few minutes doesn't redo everything.
  static const _minGap = Duration(minutes: 10);

  DateTime? _lastRun;
  Future<void>? _running;

  Future<bool> nudgesEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_nudgesKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> setNudgesEnabled(bool on) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_nudgesKey, on);
    } catch (_) {}
    Sentry.metrics.count('engagement.nudges_${on ? 'on' : 'off'}', 1);
    // The notes before and after therapy sessions follow the same switch.
    unawaited(SessionNotifications.instance.sync());
    await refresh(force: true);
  }

  /// The app opened or came back to the front.
  Future<void> appOpened() => refresh(countOpen: true);

  /// Something was just done — a check-in, a practice — so today counts
  /// and the widget should say so.
  Future<void> noteActivity() => refresh(force: true);

  Future<void> refresh({bool force = false, bool countOpen = false}) {
    if (_silent) return Future.value();
    final running = _running;
    if (running != null) return running;
    final last = _lastRun;
    if (!force && last != null && DateTime.now().difference(last) < _minGap) {
      return Future.value();
    }
    return _running = _run(countOpen: countOpen).whenComplete(() {
      _running = null;
      _lastRun = DateTime.now();
    });
  }

  Future<void> _run({required bool countOpen}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    final holdout = isEngagementHoldout(user.id);
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastOpen = DateTime.tryParse(prefs.getString(_lastOpenKey) ?? '');
      final hours = [
        if (countOpen) now.hour,
        ...?prefs.getStringList(_openHoursKey)?.map(int.tryParse).whereType<int>(),
      ].take(_hoursKept).toList();
      if (countOpen) {
        await prefs.setStringList(_openHoursKey, [for (final h in hours) '$h']);
        await prefs.setString(_lastOpenKey, now.toIso8601String());
        unawaited(_touchPresence(prefs, now));
      }

      // What's needed, side by side. Each part fails on its own.
      final results = await Future.wait<Object?>([
        _quietly(RhythmRepository().fetch()),
        _quietly(MoodRepository().fetchHistory(days: 7)),
        _quietly(_loadHealth().then((_) => true)),
        _quietly(CourseStore.instance.load().then((_) => true)),
        _quietly(TasteStore.instance.load().then((_) => true)),
      ]);
      final rhythm = results[0] as Rhythm?;
      final moods = (results[1] as List<MoodEntry>?) ?? const [];
      final premium = isPremiumUser();
      final goals = userGoals();
      final health = HealthService.instance;
      final signals = health.connected
          ? healthSignals(health.history, now)
          : const <HealthSignal>[];
      // The widget and the nudges show this pick for hours, so from
      // midnight to five it's the morning's, not the one for lying awake
      // (Home shows that one).
      final step = chooseNextStep(
        now: DayPart.of(now) == DayPart.night
            ? DateTime(now.year, now.month, now.day, 8)
            : now,
        premium: premium,
        signals: signals,
        goals: goals,
      );

      final snapshot = rhythm == null
          ? null
          : EngagementSnapshot.compute(
              activeDays: rhythm.days,
              accountCreated: DateTime.tryParse(user.createdAt) ?? now,
              now: now,
            );
      if (countOpen) {
        Sentry.metrics.count('engagement.open', 1, attributes: {
          'stage': SentryAttribute.string(snapshot?.stage.name ?? 'unknown'),
          'cohort': SentryAttribute.string(engagementCohort(user.id)),
          'health': SentryAttribute.string('${health.connected}'),
        });
      }

      if (snapshot != null) {
        await _scheduleNudges(
          snapshot: snapshot,
          rhythm: rhythm!,
          now: now,
          holdout: holdout,
          hour: nudgeHour(hours),
          lowMood: _lowMood(moods, now),
          premium: premium,
          goals: goals,
          lastOpen: lastOpen,
        );
      }

      if (rhythm != null) {
        final today = PracticeRepository.dateKey(now);
        final sleep = health.connected && health.showSleepOnWidget
            ? health.history.on(now)?.sleepMinutes
            : null;
        await HomeWidgetSync.instance.update(
          HomeWidgetSnapshot(
            daysThisWeek: rhythm.daysThisWeek,
            goal: rhythm.goal,
            week: rhythm.week,
            todayIndex: rhythm.todayIndex,
            checkedInToday: moods.any(
              (m) => PracticeRepository.dateKey(m.date) == today,
            ),
            pickId: step?.item.id,
            pickTitle: step?.item.title,
            pickMeta: step?.item.meta(),
            sleepMinutes: sleep,
          ),
        );
      }
    } catch (e) {
      debugPrint('Engagement refresh failed: ${e.runtimeType}');
    } finally {
      // The reminders' two-week window starts again from today, whatever
      // else failed.
      if (countOpen) await RemindersService.instance.refreshScheduled();
    }
  }

  static Future<T?> _quietly<T extends Object>(Future<T> future) async {
    try {
      return await future;
    } catch (e) {
      debugPrint('Engagement: a source was unavailable: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> _loadHealth() async {
    final health = HealthService.instance;
    if (health.status == HealthStatus.unknown) {
      await health.load();
    } else {
      await health.refresh();
    }
  }

  /// The latest three check-ins of the past week all "Awful" or "Low", or
  /// the latest two both "Awful". Then the app offers people, not practice.
  static bool _lowMood(List<MoodEntry> moods, DateTime now) {
    final since = DateTime(now.year, now.month, now.day - 7);
    final recent = [
      for (final m in moods)
        if (!m.date.isBefore(since)) m.index,
    ];
    if (recent.length >= 3 && recent.take(3).every((i) => i <= 1)) return true;
    return recent.length >= 2 && recent.take(2).every((i) => i == 0);
  }

  Future<void> _touchPresence(SharedPreferences prefs, DateTime now) async {
    final day = PracticeRepository.dateKey(now);
    if (prefs.getString(_presenceDayKey) == day) return;
    try {
      await Supabase.instance.client.rpc(
        'touch_app_presence',
        params: {'p_day': day},
      );
      await prefs.setString(_presenceDayKey, day);
    } catch (e) {
      // Before migration 0036, or offline: tomorrow's open tries again.
      debugPrint('Presence not recorded: ${e.runtimeType}');
    }
  }

  Future<void> _scheduleNudges({
    required EngagementSnapshot snapshot,
    required Rhythm rhythm,
    required DateTime now,
    required bool holdout,
    required int hour,
    required bool lowMood,
    required bool premium,
    required Set<Need> goals,
    required DateTime? lastOpen,
  }) async {
    await LocalNotifications.ensureInitialized();
    final plugin = LocalNotifications.plugin;
    final l10n = currentL10n();

    var hasReminders = false;
    for (final kind in ReminderKind.values) {
      if (await RemindersService.instance.isEnabled(kind)) hasReminders = true;
    }

    CourseStep? course;
    final active = CourseStore.instance.active;
    if (active != null) {
      final next = CourseStore.instance.of(active).nextDay(active);
      if (next != null) {
        course = CourseStep(
          courseId: active.id,
          courseTitle: active.title,
          dayNumber: next + 1,
        );
      }
    }
    Suggestion? asSuggestion(ContentItem? item) => item == null
        ? null
        : Suggestion(id: item.id, title: item.title, meta: item.meta(l10n));
    final suggestion = asSuggestion(
      recommend(
        needs: goals,
        count: 1,
        now: now,
        premium: premium,
        goals: goals,
      ).where((i) => premium || !i.premium).firstOrNull,
    );
    final fresh = lastOpen == null
        ? null
        : (contentIndex
                .where(
                  (i) =>
                      i.addedOn != null &&
                      i.addedOn!.isAfter(lastOpen) &&
                      (premium || !i.premium),
                )
                .toList()
              ..sort((a, b) => b.addedOn!.compareTo(a.addedOn!)))
              .firstOrNull;

    final plan = planNudges(
      l10n: l10n,
      now: now,
      snapshot: snapshot,
      enabled: await nudgesEnabled(),
      holdout: holdout,
      hour: hour,
      hasReminders: hasReminders,
      lowMood: lowMood,
      totalDays: rhythm.totalDays,
      course: course,
      suggestion: suggestion,
      newSinceLastVisit: asSuggestion(fresh),
    );

    await _cancelNudges();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'engagement_nudges',
        l10n.nudgeChannelName,
        channelDescription: l10n.nudgeChannelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        // "Contents hidden" on a lock screen set to hide sensitive content.
        visibility: NotificationVisibility.private,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );
    for (final n in plan) {
      await plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledDate: tz.TZDateTime.from(n.at, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: n.payload,
      );
    }
    Sentry.metrics.count('engagement.nudges_planned', plan.length, attributes: {
      'stage': SentryAttribute.string(snapshot.stage.name),
      'low_mood': SentryAttribute.string('$lowMood'),
    });
  }

  Future<void> _cancelNudges() async {
    final plugin = LocalNotifications.plugin;
    try {
      for (final pending in await plugin.pendingNotificationRequests()) {
        if (pending.id >= nudgeIdBase && pending.id < nudgeIdEnd) {
          await plugin.cancel(id: pending.id);
        }
      }
    } catch (e) {
      debugPrint('Couldn\'t clear nudges: ${e.runtimeType}');
    }
  }

  /// Sign-out or account deletion: no nudges for the next person on the
  /// phone, nothing of this person's on the home screen, nothing of their
  /// health in memory.
  Future<void> signedOut() async {
    _lastRun = null;
    HealthService.instance.signedOut();
    TasteStore.instance.clear();
    if (_silent) return;
    await _cancelNudges();
    await HomeWidgetSync.instance.clear();
  }

  /// A tapped nudge: count it, then open what it's about.
  void openNudge(NavigatorState navigator, String payload) {
    final parsed = parseNudgePayload(payload);
    if (parsed == null) return;
    final (kind, target) = parsed;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    Sentry.metrics.count('engagement.nudge_opened', 1, attributes: {
      'kind': SentryAttribute.string(kind.name),
      if (userId != null)
        'cohort': SentryAttribute.string(engagementCohort(userId)),
    });
    navigator.popUntil((route) => route.isFirst);
    switch (target) {
      case HomeTarget():
        homeTabRequest.value = 0;
      case SupportTarget():
        navigator.push(MaterialPageRoute(builder: (_) => const CrisisScreen()));
      case CourseTarget(:final courseId):
        final course = courses.where((c) => c.id == courseId).firstOrNull;
        if (course == null) {
          homeTabRequest.value = 0;
        } else {
          navigator.push(CourseScreen.route(course));
        }
      case ContentTarget(:final contentId):
        final item = contentIndex.where((i) => i.id == contentId).firstOrNull;
        if (item == null) {
          homeTabRequest.value = 0;
        } else {
          openContent(navigator.context, item, source: 'nudge:${kind.name}');
        }
    }
  }
}

/// For [openSessionScreen]: whether a notification payload is a nudge.
bool isNudgePayload(String payload) => payload.startsWith(nudgePayloadPrefix);


/// The win-back emails' on/off switch, kept on the account
/// (`email_preferences`, migration 0036) because the server sends them.
/// Every email also carries a link that turns them off without signing in.
abstract final class EngagementEmails {
  /// Null when it can't be read (offline, or before 0036 is applied).
  static Future<bool?> read() async {
    if (EngagementService._silent) return null;
    try {
      final on = await Supabase.instance.client.rpc('get_engagement_emails');
      return on is bool ? on : true;
    } catch (e) {
      debugPrint('Email preference unavailable: ${e.runtimeType}');
      return null;
    }
  }

  /// Throws when it couldn't be saved, so the switch can flip back.
  static Future<void> save(bool on) async {
    await Supabase.instance.client.rpc(
      'set_engagement_emails',
      params: {'p_on': on},
    );
    Sentry.metrics.count('engagement.emails_${on ? 'on' : 'off'}', 1);
  }
}
