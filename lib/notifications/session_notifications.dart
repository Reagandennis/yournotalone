import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../engagement/engagement.dart';
import '../engagement/engagement_service.dart';
import '../l10n/l10n.dart';
import '../reminders/reminders_service.dart';
import '../supabase_config.dart';
import '../therapy/session_format.dart';
import '../therapy/therapy_repository.dart';
import 'local_notifications.dart';

/// How long before a session the phone reminds you. The reminder email uses
/// the same lead (`send_session_reminders()` in migration 0010).
const sessionReminderLead = Duration(minutes: 10);

/// The WorkManager task that checks for session news in the background.
const sessionCheckTask = 'therapy-session-check';

const _keyPref = 'session_notifications_key';
const _userPref = 'session_notifications_user';
const _afterPref = 'session_notifications_after';
const _scheduledPref = 'session_notifications_scheduled';
const _companionsPref = 'session_notifications_companions';

/// Tapping the note before a session opens a journal page for what to
/// bring to it; the one after, a page for what stayed with them.
const sessionPrepPayload = 'session_prep';
const sessionReflectPayload = 'session_reflect';

/// How long before a client's session the note to gather their thoughts
/// comes: long enough to write something, after the 10-minute reminder
/// would be too late.
const sessionPrepLead = Duration(hours: 1);

NotificationDetails _details() {
  final l10n = currentL10n();
  return NotificationDetails(
    android: AndroidNotificationDetails(
      'therapy_sessions',
      l10n.notificationSessionsChannel,
      channelDescription: l10n.notificationSessionsChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      // Marked sensitive, so a phone set to hide sensitive content on the
      // lock screen shows "Contents hidden" instead of the words below.
      visibility: NotificationVisibility.private,
    ),
    iOS: const DarwinNotificationDetails(),
    macOS: const DarwinNotificationDetails(),
  );
}

/// A session's start as a comparable key: the same instant always gives the
/// same string, however the server formatted it.
String sessionStartKey(Object? scheduledAt) =>
    DateTime.parse(scheduledAt as String).toUtc().toIso8601String();

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// One reminder per session: the phone's own and the server's share an id,
/// so they can never both be on screen.
int reminderNotificationId(String sessionId) =>
    100000000 + _stableHash(sessionId) % 100000000;

/// The latest news about a session replaces the previous news about it.
int sessionNotificationId(String sessionId) =>
    200000000 + _stableHash(sessionId) % 100000000;

/// The note before a session, a separate notification from the reminder.
int prepNotificationId(String sessionId) =>
    500000000 + _stableHash(sessionId) % 100000000;

/// The note after a session.
int reflectNotificationId(String sessionId) =>
    600000000 + _stableHash(sessionId) % 100000000;

/// When the note after a session comes: in the evening of the day it
/// ended, or an hour and a half after it ended if that's later; the next
/// morning when that would be after half past nine at night.
DateTime reflectionTime(DateTime start, int minutes) {
  final end = start.add(Duration(minutes: minutes));
  final soon = end.add(const Duration(minutes: 90));
  final evening = DateTime(end.year, end.month, end.day, 18);
  final at = soon.isBefore(evening) ? evening : soon;
  if (at.isAfter(DateTime(end.year, end.month, end.day, 21, 30))) {
    return DateTime(end.year, end.month, end.day + 1, 9);
  }
  return at;
}

/// One note to schedule around a session.
typedef SessionCompanion = ({String sessionId, bool prep, DateTime at});

/// The notes before and after each of a client's sessions, kept in step
/// with the sessions as [planSessionReminders] keeps the reminders.
///
/// [scheduled] maps session id → start key for notes already scheduled.
/// A session that drops out of [upcoming] before it starts was cancelled
/// (its notes go); one that drops out after starting has simply begun, so
/// the note after it stays. News of a cancelled or missed session cancels
/// both separately (see the sync).
({
  List<SessionCompanion> schedule,
  Set<String> cancel,
  Map<String, String> remembered,
}) planSessionCompanions(
  List<Map<String, dynamic>> upcoming,
  Map<String, String> scheduled,
  DateTime now, {
  required bool enabled,
}) {
  if (!enabled) {
    return (schedule: const [], cancel: scheduled.keys.toSet(), remembered: const {});
  }
  final schedule = <SessionCompanion>[];
  final cancel = <String>{};
  final remembered = <String, String>{};
  final seen = <String>{};
  for (final session in upcoming) {
    // Therapists don't need either.
    if (session['role'] != 'client') continue;
    final id = session['request_id'] as String;
    final key = sessionStartKey(session['scheduled_at']);
    seen.add(id);
    remembered[id] = key;
    if (scheduled[id] == key) continue;
    if (scheduled.containsKey(id)) cancel.add(id);
    final start = DateTime.parse(key).toLocal();
    final prepAt = start.subtract(sessionPrepLead);
    if (prepAt.isAfter(now)) {
      schedule.add((sessionId: id, prep: true, at: prepAt));
    }
    final minutes = (session['duration_minutes'] as num?)?.toInt() ?? 50;
    final reflectAt = reflectionTime(start, minutes);
    if (reflectAt.isAfter(now)) {
      schedule.add((sessionId: id, prep: false, at: reflectAt));
    }
  }
  for (final e in scheduled.entries) {
    if (seen.contains(e.key)) continue;
    final start = DateTime.parse(e.value);
    if (start.isAfter(now)) {
      cancel.add(e.key);
    } else if (now.difference(start) < const Duration(days: 2)) {
      // Under way or over: the note after it is still to come.
      remembered[e.key] = e.value;
    }
  }
  return (schedule: schedule, cancel: cancel, remembered: remembered);
}

/// The words of a note before ([prep]) or after a session. Nothing about
/// who it's with or what it's about: it's on the lock screen.
({String title, String body}) describeSessionCompanion({required bool prep}) {
  final l10n = currentL10n();
  return prep
      ? (title: l10n.notificationPrepTitle, body: l10n.notificationPrepBody)
      : (title: l10n.notificationReflectTitle, body: l10n.notificationReflectBody);
}

/// The notes before and after a session are suggestions, so they use the
/// gentle check-ins' channel, not the sessions' urgent one.
NotificationDetails _companionDetails() {
  final l10n = currentL10n();
  return NotificationDetails(
    android: AndroidNotificationDetails(
      'engagement_nudges',
      l10n.nudgeChannelName,
      channelDescription: l10n.nudgeChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      visibility: NotificationVisibility.private,
    ),
    iOS: const DarwinNotificationDetails(),
    macOS: const DarwinNotificationDetails(),
  );
}

/// A notification's words, written on the phone so times are in its own
/// time zone. [data] is what `session_notification_data()` queues.
///
/// The session's topic ("Grief & loss", "Addiction & recovery") is never
/// part of it: a notification sits on the lock screen where anyone holding
/// the phone can read it. What the session is about stays in the app.
({String title, String body}) describeSessionNotification(
  String kind,
  Map<String, dynamic> data,
  DateTime now,
) {
  final l10n = currentL10n();
  final client = data['role'] != 'therapist';
  final name = (data['counterpart'] as String?)?.trim() ?? '';
  final who = name.isNotEmpty
      ? name
      : client
          ? l10n.notificationYourTherapist
          : l10n.notificationYourClient;
  final at = data['scheduled_at'] == null
      ? null
      : DateTime.parse(data['scheduled_at'] as String).toLocal();
  final when = at == null ? l10n.notificationBookedTime : formatDateTime(at);
  final minutes = (data['duration_minutes'] as num?)?.toInt() ?? 50;
  final unpaid = data['payment_status'] == 'unpaid';
  // In the session's own currency once the payload names it; dollars for
  // payloads from before sessions were priced by country.
  final price = formatPrice(
    (data['price_cents'] as num?)?.toInt() ?? 0,
    data['currency'] as String? ?? 'USD',
  );

  switch (kind) {
    case 'session_booked':
      if (client) {
        return (
          title: l10n.notificationMatchedTitle(who),
          body: unpaid
              ? l10n.notificationMatchedBodyUnpaid(when, minutes, price)
              : l10n.notificationMatchedBodyPaid(when, minutes),
        );
      }
      return (
        title: l10n.notificationNewSessionTitle(who),
        body: unpaid
            ? l10n.notificationNewSessionBodyUnpaid(when, minutes)
            : l10n.notificationNewSessionBody(when, minutes),
      );
    case 'session_changed':
      return client
          ? (
              title: l10n.notificationChangedTitle,
              body: l10n.notificationChangedBody(when, who, minutes),
            )
          : (
              title: l10n.notificationUpdatedTitle,
              body: l10n.notificationUpdatedBody(who, when, minutes),
            );
    case 'session_cancelled':
      return (
        title: l10n.notificationCancelledTitle,
        body: l10n.notificationCancelledBody(who, when),
      );
    case 'session_missed':
      // Only the client is told; the therapist was there.
      return (
        title: l10n.notificationMissedTitle,
        body: l10n.notificationMissedBody(who, when),
      );
    case 'session_reminder':
      final left =
          at == null ? 10 : max(0, (at.difference(now).inSeconds / 60).ceil());
      final hasTime = at == null ? 'no' : 'yes';
      final time = at == null ? '' : formatTime(at);
      return client
          ? (
              title: l10n.notificationReminderClientTitle(left),
              body: unpaid
                  ? l10n.notificationReminderClientBodyUnpaid(
                      hasTime, who, time)
                  : l10n.notificationReminderClientBody(hasTime, who, time),
            )
          : (
              title: l10n.notificationReminderTherapistTitle(left, who),
              body: unpaid
                  ? l10n.notificationReminderTherapistBodyUnpaid(hasTime, time)
                  : l10n.notificationReminderTherapistBody(hasTime, time),
            );
  }
  return (
    title: l10n.notificationGenericTitle,
    body: l10n.notificationGenericBody,
  );
}

/// News that arrives too late to be useful stays quiet: a reminder once the
/// session is well under way, anything else once it's long over.
bool isStaleSessionNotification(
  String kind,
  Map<String, dynamic> data,
  DateTime now,
) {
  if (data['scheduled_at'] == null) return false;
  final start = DateTime.parse(data['scheduled_at'] as String);
  if (kind == 'session_reminder') {
    return now.isAfter(start.add(const Duration(minutes: 15)));
  }
  final minutes = (data['duration_minutes'] as num?)?.toInt() ?? 50;
  return now.isAfter(start.add(Duration(minutes: minutes + 60)));
}

/// Keeps the phone's own reminders in step with the sessions coming up.
///
/// [scheduled] maps session id → start key for reminders already scheduled.
/// Returns the reminders to schedule, the session ids whose reminders to
/// cancel, and the map to remember next time.
({
  List<Map<String, dynamic>> schedule,
  Set<String> cancel,
  Map<String, String> remembered,
}) planSessionReminders(
  List<Map<String, dynamic>> upcoming,
  Map<String, String> scheduled,
  DateTime now,
) {
  final schedule = <Map<String, dynamic>>[];
  final cancel = <String>{};
  final remembered = <String, String>{};
  final seen = <String>{};

  for (final session in upcoming) {
    final id = session['request_id'] as String;
    final start = sessionStartKey(session['scheduled_at']);
    seen.add(id);
    if (scheduled[id] == start) {
      remembered[id] = start;
      continue;
    }
    // Moved: the old reminder must not fire at the old time.
    if (scheduled.containsKey(id)) cancel.add(id);
    if (DateTime.parse(start).subtract(sessionReminderLead).isAfter(now)) {
      schedule.add(session);
      remembered[id] = start;
    }
  }
  for (final id in scheduled.keys) {
    if (!seen.contains(id)) cancel.add(id);
  }
  return (schedule: schedule, cancel: cancel, remembered: remembered);
}

/// Of the reminders [stored] (session id → start key), those to keep taking
/// as scheduled: the ones still among the phone's [pending] notification
/// ids, and the ones whose time has come (fired already, so no longer
/// pending, and not to be shown twice).
Map<String, String> keepStillScheduled(
  Map<String, String> stored,
  Set<int> pending,
  DateTime now,
) => {
  for (final entry in stored.entries)
    if (pending.contains(reminderNotificationId(entry.key)) ||
        !DateTime.parse(entry.value).subtract(sessionReminderLead).isAfter(now))
      entry.key: entry.value,
};

/// Phone notifications for therapy sessions, without a push service.
///
/// Each install registers a random key with the server. With that key alone
/// the app — or its background task, about every 15 minutes on Android —
/// collects news queued by migration 0010 (booked, changed, cancelled,
/// reminders), shows it, and schedules each upcoming session's reminder on
/// the phone. The key is used instead of the signed-in session because
/// refreshing that session from a background isolate would race the app and
/// could sign people out.
class SessionNotifications {
  SessionNotifications._();

  static final instance = SessionNotifications._();

  static final bool _silent = Platform.environment.containsKey('FLUTTER_TEST');

  late final _prefs = SharedPreferencesAsync();

  FlutterLocalNotificationsPlugin get _plugin => LocalNotifications.plugin;

  /// Everything that touches this install's registration runs one at a
  /// time. [start] is called from several screens and on every resume,
  /// often within the same second; on a first launch each call would
  /// otherwise find no key yet, register a key of its own, and leave the
  /// server with orphan devices whose news nobody ever collects.
  Future<void> _chain = Future.value();

  Future<T> _serially<T>(Future<T> Function() task) {
    final run = _chain.then((_) => task());
    _chain = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  /// A [start] waiting for its turn; further calls join it rather than
  /// queueing another round trip.
  Future<void>? _queuedStart;
  bool _queuedAsk = false;

  /// Registers this install for whoever is signed in, catches up, and turns
  /// background checks on or off depending on whether there's a session to
  /// watch. Cheap enough to call on every launch and resume.
  Future<void> start({bool askPermission = false}) {
    if (_silent) return Future.value();
    _queuedAsk = _queuedAsk || askPermission;
    return _queuedStart ??= _serially(() {
      _queuedStart = null;
      final ask = _queuedAsk;
      _queuedAsk = false;
      return _start(askPermission: ask);
    });
  }

  Future<void> _start({required bool askPermission}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      if (askPermission) await RemindersService.instance.requestPermission();
      await _register(user.id);
      final active = await _sync();
      if (Platform.isAndroid) {
        if (active) {
          await Workmanager().registerPeriodicTask(
            sessionCheckTask,
            sessionCheckTask,
            frequency: const Duration(minutes: 15),
            constraints: Constraints(networkType: NetworkType.connected),
            existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
          );
        } else {
          await Workmanager().cancelByUniqueName(sessionCheckTask);
        }
      }
    } catch (e) {
      debugPrint('Session notifications unavailable: $e');
    }
  }

  /// On sign-out: forget this install on the server while the session still
  /// allows it, stop checking, and drop any scheduled reminders.
  Future<void> stop() {
    if (_silent) return Future.value();
    return _serially(_stop);
  }

  Future<void> _stop() async {
    try {
      final key = await _prefs.getString(_keyPref);
      if (key != null && Supabase.instance.client.auth.currentUser != null) {
        await Supabase.instance.client.rpc(
          'unregister_notification_device',
          params: {'p_key': key},
        );
      }
    } catch (e) {
      debugPrint('Couldn\'t unregister this device: $e');
    }
    await _forget();
  }

  /// Collects news and upcoming sessions with this install's key. Returns
  /// whether there's anything worth checking for again. Needs no Supabase
  /// session, so it runs the same in the background.
  Future<bool> sync() {
    if (_silent) return Future.value(false);
    return _serially(_sync);
  }

  Future<void> _register(String userId) async {
    final key = await _prefs.getString(_keyPref);
    final owner = await _prefs.getString(_userPref);
    if (key != null && owner == userId) return;
    // Someone else used to be signed in here: their reminders go too.
    if (key != null) await _forget();

    final random = Random.secure();
    final newKey =
        base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
    final after = await Supabase.instance.client.rpc(
      'register_notification_device',
      params: {
        'p_key': newKey,
        'p_platform': Platform.isAndroid
            ? 'android'
            : Platform.isIOS
                ? 'ios'
                : Platform.isMacOS
                    ? 'macos'
                    : 'other',
      },
    );
    await _prefs.setString(_keyPref, newKey);
    await _prefs.setString(_userPref, userId);
    await _prefs.setInt(_afterPref, (after as num).toInt());
  }

  /// With [ifKey], only if that's still this install's key: the background
  /// isolate and the app share these preferences but not the lock above,
  /// so a check that started before a sign-out or sign-in must not throw
  /// away the registration made since.
  Future<void> _forget({String? ifKey}) async {
    if (ifKey != null && await _prefs.getString(_keyPref) != ifKey) return;
    try {
      if (Platform.isAndroid) {
        await Workmanager().cancelByUniqueName(sessionCheckTask);
      }
      await LocalNotifications.ensureInitialized();
      for (final id in (await _scheduled()).keys) {
        await _plugin.cancel(id: reminderNotificationId(id));
      }
      for (final id in (await _companions()).keys) {
        await _cancelCompanions(id);
      }
    } catch (e) {
      debugPrint('Couldn\'t clear session reminders: $e');
    }
    for (final pref in [
      _keyPref,
      _userPref,
      _afterPref,
      _scheduledPref,
      _companionsPref,
    ]) {
      await _prefs.remove(pref);
    }
  }

  Future<Map<String, String>> _scheduled() async {
    final stored = await _prefs.getString(_scheduledPref);
    if (stored == null) return {};
    return Map<String, String>.from(jsonDecode(stored) as Map);
  }

  Future<Map<String, String>> _companions() async {
    final stored = await _prefs.getString(_companionsPref);
    if (stored == null) return {};
    return Map<String, String>.from(jsonDecode(stored) as Map);
  }

  Future<void> _cancelCompanions(String sessionId) async {
    await _plugin.cancel(id: prepNotificationId(sessionId));
    await _plugin.cancel(id: reflectNotificationId(sessionId));
  }

  /// The notes before and after sessions go with the gentle check-ins:
  /// off when those are, and not for the comparison group that keeps the
  /// app as it was (lib/engagement/engagement.dart).
  Future<bool> _companionsWanted() async {
    final user = await _prefs.getString(_userPref);
    if (user == null || isEngagementHoldout(user)) return false;
    return EngagementService.instance.nudgesEnabled();
  }

  Future<Map<String, String>> _syncCompanions(
    List<Map<String, dynamic>> upcoming,
    DateTime now,
  ) async {
    final plan = planSessionCompanions(
      upcoming,
      await _companions(),
      now,
      enabled: await _companionsWanted(),
    );
    for (final id in plan.cancel) {
      await _cancelCompanions(id);
    }
    for (final note in plan.schedule) {
      final text = describeSessionCompanion(prep: note.prep);
      await _plugin.zonedSchedule(
        id: note.prep
            ? prepNotificationId(note.sessionId)
            : reflectNotificationId(note.sessionId),
        scheduledDate: tz.TZDateTime.from(note.at, tz.local),
        notificationDetails: _companionDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: text.title,
        body: text.body,
        payload: note.prep ? sessionPrepPayload : sessionReflectPayload,
      );
    }
    return plan.remembered;
  }

  Future<bool> _sync() async {
    final key = await _prefs.getString(_keyPref);
    if (key == null) return false;
    final after = await _prefs.getInt(_afterPref) ?? 0;

    final result = await _deviceSync(key, after);
    // Re-registered meanwhile (a sign-out and sign-in from the app while
    // this ran in the background): these results belong to the old key.
    if (await _prefs.getString(_keyPref) != key) return false;
    if (result['registered'] != true) {
      await _forget(ifKey: key);
      return false;
    }
    await LocalNotifications.ensureInitialized();
    final stored = await _scheduled();
    final pending = await _pendingIds(stored);
    // Read after the pending lookup: a reminder that fires during it is no
    // longer pending, and must count as due, not as dropped (scheduling it
    // again, now in the past, would fail the whole sync).
    final now = DateTime.now();

    // Reminders for what's coming up, scheduled on the phone itself.
    final upcoming = [
      for (final session in result['upcoming'] as List? ?? const [])
        Map<String, dynamic>.from(session as Map),
    ];
    final plan = planSessionReminders(
      upcoming,
      pending == null ? stored : keepStillScheduled(stored, pending, now),
      now,
    );
    for (final id in plan.cancel) {
      await _plugin.cancel(id: reminderNotificationId(id));
    }
    for (final session in plan.schedule) {
      final remindAt = DateTime.parse(session['scheduled_at'] as String)
          .subtract(sessionReminderLead);
      final text =
          describeSessionNotification('session_reminder', session, remindAt);
      await _plugin.zonedSchedule(
        id: reminderNotificationId(session['request_id'] as String),
        scheduledDate: tz.TZDateTime.from(remindAt, tz.local),
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: text.title,
        body: text.body,
        payload: session['role'] as String?,
      );
    }
    await _prefs.setString(_scheduledPref, jsonEncode(plan.remembered));
    final companions = await _syncCompanions(upcoming, now);

    // News since the last check. Each item is passed over once tried,
    // shown or not: one that can't be read or shown is skipped, rather than
    // failing the check and coming back every 15 minutes with everything
    // after it held up behind it.
    var last = after;
    for (final raw in result['notifications'] as List? ?? const []) {
      try {
        final notification = Map<String, dynamic>.from(raw as Map);
        final id = (notification['id'] as num?)?.toInt();
        if (id != null && id > last) last = id;
        // No "after your session" for one that didn't happen.
        final kind = notification['kind'];
        final data = notification['data'];
        if ((kind == 'session_cancelled' || kind == 'session_missed') &&
            data is Map) {
          final sessionId = data['request_id'];
          if (sessionId is String && companions.remove(sessionId) != null) {
            await _cancelCompanions(sessionId);
          }
        }
        await _showNews(notification, plan.remembered, now);
      } catch (e) {
        debugPrint('Skipped a session notification: $e');
      }
      await _prefs.setInt(_afterPref, last);
    }
    await _prefs.setInt(_afterPref, last);
    await _prefs.setString(_companionsPref, jsonEncode(companions));
    return result['active'] == true;
  }

  Future<void> _showNews(
    Map<String, dynamic> notification,
    Map<String, String> remembered,
    DateTime now,
  ) async {
    final kind = notification['kind'] as String;
    final data = Map<String, dynamic>.from(notification['data'] as Map);
    final sessionId = data['request_id'] as String;
    if (isStaleSessionNotification(kind, data, now)) return;
    // The phone already has its own reminder for this session and time.
    if (kind == 'session_reminder' &&
        data['scheduled_at'] != null &&
        remembered[sessionId] == sessionStartKey(data['scheduled_at'])) {
      return;
    }
    final text = describeSessionNotification(kind, data, now);
    await _plugin.show(
      id: kind == 'session_reminder'
          ? reminderNotificationId(sessionId)
          : sessionNotificationId(sessionId),
      title: text.title,
      body: text.body,
      notificationDetails: _details(),
      payload: data['role'] as String?,
    );
  }

  /// The notification ids the phone still has pending, so a reminder in
  /// [stored] the system dropped (an update, a reboot on some phones,
  /// "clear all", the app force-stopped) is scheduled again rather than
  /// taken as done (see [keepStillScheduled]). Null when there's nothing
  /// stored, or the phone can't say: then [stored] is kept as it is.
  Future<Set<int>?> _pendingIds(Map<String, String> stored) async {
    if (stored.isEmpty) return null;
    try {
      return {
        for (final request in await _plugin.pendingNotificationRequests())
          request.id,
      };
    } catch (e) {
      debugPrint('Pending notifications unavailable: $e');
      return null;
    }
  }

  /// `device_session_sync` over plain HTTP: the key is the credential.
  Future<Map<String, dynamic>> _deviceSync(String key, int after) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client
          .postUrl(Uri.parse('$supabaseUrl/rest/v1/rpc/device_session_sync'));
      request.headers
        ..set('apikey', supabasePublishableKey)
        ..contentType = ContentType.json;
      request.write(jsonEncode({'p_key': key, 'p_after': after}));
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode != 200) {
        throw HttpException(
            'device_session_sync ${response.statusCode}: $body');
      }
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    } finally {
      client.close();
    }
  }
}

/// WorkManager's entry point: a background isolate, about every 15 minutes
/// while there's a session to keep an eye on.
@pragma('vm:entry-point')
void sessionNotificationsCallback() {
  Workmanager().executeTask((task, inputData) async {
    DartPluginRegistrant.ensureInitialized();
    try {
      // A fresh isolate: the notifications are written in the language
      // picked in Settings, if any, with that language's day and month
      // names (loaded in the app's own isolate at start-up, not here).
      await LocaleSetting.instance.load();
      await initializeDateFormatting();
      final active = await SessionNotifications.instance.sync();
      if (!active) await Workmanager().cancelByUniqueName(sessionCheckTask);
    } catch (e) {
      debugPrint('Background session check failed: $e');
    }
    // Always "done": a failed check just waits for the next one.
    return true;
  });
}
