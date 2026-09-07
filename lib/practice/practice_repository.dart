import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../brand.dart';

/// What kind of practice a session was.
enum PracticeKind {
  meditation('meditation', 'Meditation', Icons.self_improvement_rounded,
      Brand.blue),
  breathing('breathing', 'Breathing', Icons.air_rounded, Brand.yellow),
  sound('sound', 'Sound', Icons.graphic_eq_rounded, Brand.ink);

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
class PracticeRepository {
  PracticeRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Calendar date in the user's own zone, matching [MoodRepository.dateKey].
  static String dateKey(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  String? get _userId => _client.auth.currentUser?.id;

  /// Records a finished session. Never throws: losing a history row must
  /// not turn a calm moment into an error message.
  Future<void> logSession({
    required PracticeKind kind,
    required String slug,
    required String title,
    required double minutes,
  }) async {
    final userId = _userId;
    if (userId == null || minutes <= 0) return;
    try {
      await _client.from('practice_sessions').insert({
        'user_id': userId,
        'kind': kind.key,
        'slug': slug,
        'title': title,
        'minutes': minutes,
      });
    } catch (error) {
      debugPrint('Could not record practice session: $error');
    }
  }

  Future<List<PracticeSession>> fetchRecent({int days = 120}) async {
    final userId = _userId;
    if (userId == null) return const [];
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _client
        .from('practice_sessions')
        .select()
        .eq('user_id', userId)
        .gte('completed_at', since.toUtc().toIso8601String())
        .order('completed_at', ascending: false);
    return [for (final row in rows) PracticeSession.fromMap(row)];
  }

  Future<PracticeSummary> fetchSummary({int days = 120}) async =>
      summarise(await fetchRecent(days: days));

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
