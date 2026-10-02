// The network hooks are private fields set from named parameters, which
// Dart can't express as initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';
import 'pending_practice.dart';

/// What kind of practice a session was.
enum PracticeKind {
  meditation('meditation', 'Meditation', Icons.self_improvement_rounded,
      Pillars.blue),
  breathing('breathing', 'Breathing', Icons.air_rounded, Pillars.yellow),
  sound('sound', 'Sound', Icons.graphic_eq_rounded, Pillars.black);

  const PracticeKind(this.key, this.label, this.icon, this.color);

  /// Stored in the database — never change these.
  final String key;
  final String label;
  final IconData icon;
  final Color color;

  static PracticeKind fromKey(String key) =>
      values.firstWhere((k) => k.key == key, orElse: () => meditation);
}

/// One finished session.
class PracticeSession {
  const PracticeSession({
    required this.kind,
    required this.slug,
    required this.title,
    required this.minutes,
    required this.completedAt,
  });

  final PracticeKind kind;
  final String slug;
  final String title;
  final double minutes;
  final DateTime completedAt;

  factory PracticeSession.fromMap(Map<String, dynamic> map) => PracticeSession(
        kind: PracticeKind.fromKey(map['kind'] as String),
        slug: map['slug'] as String,
        title: map['title'] as String,
        minutes: (map['minutes'] as num).toDouble(),
        completedAt:
            DateTime.parse(map['completed_at'] as String).toLocal(),
      );
}

/// What the history adds up to — the numbers Home and the practice screen
/// both want.
class PracticeSummary {
  const PracticeSummary({
    required this.sessions,
    required this.totalMinutes,
    required this.minutesThisWeek,
    required this.dayStreak,
    required this.last,
  });

  static const empty = PracticeSummary(
    sessions: 0,
    totalMinutes: 0,
    minutesThisWeek: 0,
    dayStreak: 0,
    last: null,
  );

  final int sessions;
  final double totalMinutes;
  final double minutesThisWeek;

  /// Consecutive days up to today with at least one session. Today not
  /// being practised yet doesn't break it — the day isn't over.
  final int dayStreak;

  /// The most recent session, for "pick up where you left off".
  final PracticeSession? last;

  bool get isEmpty => sessions == 0;
}

/// Practice history, backed by the `practice_sessions` table.
///
/// Writes go through a device-side queue ([PendingPracticeStore]) first, so
/// a session finished on a dead connection, or while the app is being
/// killed, is not lost: it's sent on the next attempt, launch, or resume.
class PracticeRepository {
  PracticeRepository({
    SupabaseClient? client,
    PendingPracticeStore? pending,
    Future<void> Function(Map<String, dynamic> row)? insert,
    Future<List<Map<String, dynamic>>> Function(String userId, DateTime since)?
        fetchRows,
    String? Function()? currentUserId,
  })  : _client = client ?? Supabase.instance.client,
        _pending = pending ?? PendingPracticeStore(),
        _insert = insert,
        _fetchRows = fetchRows,
        _currentUserId = currentUserId;

  final SupabaseClient _client;
  final PendingPracticeStore _pending;

  /// The network calls, injectable so the queue can be tested offline.
  final Future<void> Function(Map<String, dynamic> row)? _insert;
  final Future<List<Map<String, dynamic>>> Function(
      String userId, DateTime since)? _fetchRows;
  final String? Function()? _currentUserId;

  /// A dead connection mustn't hold a request open indefinitely.
  static const _writeTimeout = Duration(seconds: 20);

  /// Calendar date in the user's own zone, matching [MoodRepository.dateKey].
  static String dateKey(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  String? get _userId =>
      _currentUserId != null ? _currentUserId() : _client.auth.currentUser?.id;

  Future<void> _insertRow(Map<String, dynamic> row) => _insert != null
      ? _insert(row)
      : _client.from('practice_sessions').insert(row).timeout(_writeTimeout);

  Future<List<Map<String, dynamic>>> _rowsSince(
      String userId, DateTime since) async {
    if (_fetchRows != null) return _fetchRows(userId, since);
    final rows = await _client
        .from('practice_sessions')
        .select()
        .eq('user_id', userId)
        .gte('completed_at', since.toUtc().toIso8601String())
        .order('completed_at', ascending: false);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }

  /// Records a finished session. Never throws: losing a history row must
  /// not turn a calm moment into an error message.
  ///
  /// The session is saved on the device first, then sent along with
  /// anything older still waiting. Callers don't need to await this.
  Future<void> logSession({
    required PracticeKind kind,
    required String slug,
    required String title,
    required double minutes,
  }) async {
    final userId = _userId;
    if (userId == null || minutes <= 0) return;
    try {
      await _pending.add(PendingPracticeSession(
        id: _uuidV4(),
        userId: userId,
        kind: kind,
        slug: slug,
        title: title,
        minutes: minutes,
        completedAt: DateTime.now(),
      ));
    } catch (error) {
      debugPrint('Could not queue practice session: $error');
    }
    await flushPending();
  }

  bool _flushing = false;

  /// Sends whatever the signed-in user has waiting, oldest first, stopping
  /// at the first failure (the connection is down; try again later).
  /// Returns how many were written. Never throws.
  Future<int> flushPending() async {
    if (_flushing) return 0;
    _flushing = true;
    var sent = 0;
    try {
      final userId = _userId;
      if (userId == null) return 0;
      final waiting = (await _pending.all())
          .where((s) => s.userId == userId)
          .toList()
        ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
      for (final session in waiting) {
        if (!await _send(session)) break;
        sent++;
      }
    } catch (error) {
      debugPrint('Practice sync failed: $error');
    } finally {
      _flushing = false;
    }
    return sent;
  }

  /// True once the server has this session, whether it just took it or
  /// already had it from an attempt whose response never arrived.
  Future<bool> _send(PendingPracticeSession session) async {
    try {
      await _insertRow(session.toJson());
      Sentry.metrics.count('practice.completed.${session.kind.key}', 1);
    } on PostgrestException catch (error) {
      // 23505: the row is already there.
      if (error.code != '23505') {
        debugPrint('Could not record practice session: $error');
        return false;
      }
    } catch (error) {
      debugPrint('Could not record practice session: $error');
      return false;
    }
    await _pending.remove(session.id);
    return true;
  }

  /// The server's history plus anything still waiting on this device, so a
  /// session finished offline shows up straight away.
  Future<List<PracticeSession>> fetchRecent({int days = 120}) async {
    final userId = _userId;
    if (userId == null) return const [];
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _rowsSince(userId, since);
    final sessions = [for (final row in rows) PracticeSession.fromMap(row)];
    final waiting = await _pending.all();
    for (final pending in waiting) {
      if (pending.userId == userId && pending.completedAt.isAfter(since)) {
        sessions.add(pending.toSession());
      }
    }
    sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return sessions;
  }

  Future<PracticeSummary> fetchSummary({int days = 120}) async =>
      summarise(await fetchRecent(days: days));

  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')]
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static final _random = Random.secure();

  /// Pure, so the maths can be tested without a backend.
  static PracticeSummary summarise(List<PracticeSession> sessions) {
    if (sessions.isEmpty) return PracticeSummary.empty;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    var total = 0.0;
    var week = 0.0;
    final practisedDays = <String>{};
    for (final session in sessions) {
      total += session.minutes;
      if (!session.completedAt.isBefore(weekStart)) week += session.minutes;
      practisedDays.add(dateKey(session.completedAt));
    }

    var streak = 0;
    for (var back = 0; back < 400; back++) {
      final day = DateTime(today.year, today.month, today.day - back);
      if (!practisedDays.contains(dateKey(day))) {
        // The day isn't over yet, so today alone doesn't end a streak.
        if (back == 0) continue;
        break;
      }
      streak++;
    }

    final ordered = [...sessions]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return PracticeSummary(
      sessions: sessions.length,
      totalMinutes: total,
      minutesThisWeek: week,
      dayStreak: streak,
      last: ordered.first,
    );
  }
}
