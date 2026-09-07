import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Milestones celebrated along a streak, in days.
const recoveryMilestones = [
  (1, 'Day one'),
  (3, '3 days'),
  (7, '1 week'),
  (14, '2 weeks'),
  (30, '1 month'),
  (60, '2 months'),
  (90, '90 days'),
  (180, '6 months'),
  (365, '1 year'),
];

class RecoveryHabit {
  const RecoveryHabit({
    required this.id,
    required this.name,
    required this.dayOne,
    required this.bestStreakDays,
    required this.pledgedToday,
  });

  final String id;
  final String name;
  final DateTime dayOne;
  final int bestStreakDays;
  final bool pledgedToday;

  /// "Day 1" on the start date itself.
  int get daysIn {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(dayOne.year, dayOne.month, dayOne.day);
    return math.max(1, today.difference(start).inDays + 1);
  }

  /// The next milestone ahead, or null when past them all.
  (int, String)? get nextMilestone {
    for (final m in recoveryMilestones) {
      if (daysIn < m.$1) return m;
    }
    return null;
  }

  /// Progress 0..1 from the previous milestone to the next.
  double get milestoneProgress {
    final next = nextMilestone;
    if (next == null) return 1;
    var previous = 0;
    for (final m in recoveryMilestones) {
      if (m.$1 >= next.$1) break;
      previous = m.$1;
    }
    return (daysIn - previous) / (next.$1 - previous);
  }
}

class CravingLog {
  const CravingLog({
    required this.id,
    required this.intensity,
    required this.trigger,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final int intensity;
  final String trigger;
  final String? note;
  final DateTime createdAt;

  factory CravingLog.fromMap(Map<String, dynamic> map) => CravingLog(
        id: map['id'] as String,
        intensity: map['intensity'] as int,
        trigger: map['trigger_kind'] as String,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );

  /// Rough part of the day, for spotting when cravings tend to land.
  String get partOfDay {
    final hour = createdAt.hour;
    if (hour < 6) return 'Night';
    if (hour < 12) return 'Morning';
    if (hour < 18) return 'Afternoon';
    return 'Evening';
  }
}

/// Supabase-backed storage for commitments, pledges, and craving logs.
class RecoveryRepository {
  final _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  Future<List<RecoveryHabit>> fetchHabits() async {
    final rows = await _client
        .from('recovery_habits')
        .select()
        .eq('user_id', _userId)
        .order('created_at');
    final pledges = await _client
        .from('recovery_pledges')
        .select('habit_id')
        .eq('user_id', _userId)
        .eq('pledge_date', _today());
    final pledged = {for (final p in pledges) p['habit_id'] as String};
    return [
      for (final row in rows)
        RecoveryHabit(
          id: row['id'] as String,
          name: row['name'] as String,
          dayOne: DateTime.parse(row['day_one'] as String),
          bestStreakDays: row['best_streak_days'] as int,
          pledgedToday: pledged.contains(row['id'] as String),
        ),
    ];
  }

  Future<void> addHabit(String name, DateTime dayOne) =>
      _client.from('recovery_habits').insert({
        'user_id': _userId,
        'name': name,
        'day_one': dayOne.toIso8601String().substring(0, 10),
      });

  /// Starts the count over, preserving the best streak so far.
  Future<void> resetDayOne(RecoveryHabit habit) =>
      _client.from('recovery_habits').update({
        'day_one': _today(),
        'best_streak_days': math.max(habit.bestStreakDays, habit.daysIn),
      }).eq('id', habit.id);

  Future<void> deleteHabit(String id) =>
      _client.from('recovery_habits').delete().eq('id', id);

  Future<void> pledgeToday(String habitId) =>
      _client.from('recovery_pledges').upsert(
        {
          'user_id': _userId,
          'habit_id': habitId,
          'pledge_date': _today(),
        },
        onConflict: 'habit_id,pledge_date',
      );

  Future<List<CravingLog>> fetchRecentCravings({int limit = 15}) async {
    final rows = await _client
        .from('craving_logs')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final row in rows) CravingLog.fromMap(row)];
  }

  /// Everything logged in the last [days] days — the pool the insights
  /// screen reads patterns from.
  Future<List<CravingLog>> fetchCravings({int days = 90}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await _client
        .from('craving_logs')
        .select()
        .eq('user_id', _userId)
        .gte('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return [for (final row in rows) CravingLog.fromMap(row)];
  }

  Future<void> logCraving({
    required int intensity,
    required String trigger,
    String? note,
  }) =>
      _client.from('craving_logs').insert({
        'user_id': _userId,
        'intensity': intensity,
        'trigger_kind': trigger,
        if (note != null && note.isNotEmpty) 'note': note,
      });
}
