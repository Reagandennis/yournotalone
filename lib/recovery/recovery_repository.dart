import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../calendar_days.dart';
import '../l10n/l10n.dart';

/// Milestones celebrated along a streak, in days.
const recoveryMilestoneDays = [1, 3, 7, 14, 30, 60, 90, 180, 365];

/// How a milestone is named: "Day one", "1 week", "6 months"…
String recoveryMilestoneLabel(AppLocalizations l10n, int days) =>
    switch (days) {
      1 => l10n.recoveryMilestoneDayOne,
      7 || 14 => l10n.recoveryMilestoneWeeks(days ~/ 7),
      30 || 60 || 180 => l10n.recoveryMilestoneMonths(days ~/ 30),
      365 => l10n.recoveryMilestoneYears(1),
      _ => l10n.recoveryMilestoneDays(days),
    };

/// The milestones with their names in the language of [l10n].
List<(int, String)> recoveryMilestonesIn(AppLocalizations l10n) => [
      for (final days in recoveryMilestoneDays)
        (days, recoveryMilestoneLabel(l10n, days)),
    ];

/// [recoveryMilestonesIn] the app's current language.
List<(int, String)> get recoveryMilestones =>
    recoveryMilestonesIn(currentL10n());

/// What can set a craving off. Saved as is in `craving_logs.trigger_kind`,
/// so never change these; [recoveryTriggerLabel] names them on screen.
const recoveryTriggerKinds = [
  'Stress',
  'Boredom',
  'Loneliness',
  'Social pressure',
  'Tiredness',
  'Habit',
  'Other',
];

/// A saved trigger kind, named in the language of [l10n]. Anything not in
/// [recoveryTriggerKinds] is shown as it was saved.
String recoveryTriggerLabel(AppLocalizations l10n, String kind) =>
    switch (kind) {
      'Stress' => l10n.recoveryTriggerStress,
      'Boredom' => l10n.recoveryTriggerBoredom,
      'Loneliness' => l10n.recoveryTriggerLoneliness,
      'Social pressure' => l10n.recoveryTriggerSocialPressure,
      'Tiredness' => l10n.recoveryTriggerTiredness,
      'Habit' => l10n.recoveryTriggerHabit,
      'Other' => l10n.recoveryTriggerOther,
      _ => kind,
    };

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

  /// "Day 1" on the start date itself. Counted in calendar days, so the
  /// night the clocks go forward doesn't take one away; it's also what the
  /// best streak keeps when the count starts over.
  int get daysIn =>
      math.max(1, calendarDaysBetween(dayOne, clock.now()) + 1);

  /// The next milestone ahead, or null when past them all.
  (int, String)? get nextMilestone => nextMilestoneIn(currentL10n());

  /// [nextMilestone], named in the language of [l10n].
  (int, String)? nextMilestoneIn(AppLocalizations l10n) {
    for (final days in recoveryMilestoneDays) {
      if (daysIn < days) return (days, recoveryMilestoneLabel(l10n, days));
    }
    return null;
  }

  /// Progress 0..1 from the previous milestone to the next.
  double get milestoneProgress {
    int? next;
    for (final days in recoveryMilestoneDays) {
      if (daysIn < days) {
        next = days;
        break;
      }
    }
    if (next == null) return 1;
    var previous = 0;
    for (final days in recoveryMilestoneDays) {
      if (days >= next) break;
      previous = days;
    }
    return (daysIn - previous) / (next - previous);
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

  /// Rough part of the day, for spotting when cravings tend to land: one
  /// of [partsOfDay], named on screen by [partOfDayLabel].
  String get partOfDay {
    final hour = createdAt.hour;
    if (hour < 6) return 'night';
    if (hour < 12) return 'morning';
    if (hour < 18) return 'afternoon';
    return 'evening';
  }

  static const partsOfDay = ['morning', 'afternoon', 'evening', 'night'];

  /// A [partOfDay] in the language of [l10n]: "Morning", "Night"…
  static String partOfDayLabel(AppLocalizations l10n, String part) =>
      switch (part) {
        'morning' => l10n.recoveryPartOfDayMorning,
        'afternoon' => l10n.recoveryPartOfDayAfternoon,
        'evening' => l10n.recoveryPartOfDayEvening,
        _ => l10n.recoveryPartOfDayNight,
      };
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
  ///
  /// The phone's copy may be stale: another device may have reset the
  /// count (a new day one, so this streak isn't the one that ended) or
  /// recorded a better best. So the write only lands on the row as the
  /// phone saw it, and never lowers the best on the server; otherwise the
  /// row is read again and the reset worked out from that, once.
  Future<void> resetDayOne(RecoveryHabit habit) => resetDayOneGuarded(
    habit,
    today: _today(),
    update: (seen, values) async {
      final rows = await _client
          .from('recovery_habits')
          .update(values)
          .eq('id', habit.id)
          .eq('day_one', seen.day)
          .lte('best_streak_days', values['best_streak_days'] as int)
          .select('id');
      return rows.isNotEmpty;
    },
    reload: () async {
      final row = await _client
          .from('recovery_habits')
          .select('day_one, best_streak_days')
          .eq('id', habit.id)
          .maybeSingle();
      if (row == null) return null;
      return (
        day: (row['day_one'] as String).substring(0, 10),
        best: (row['best_streak_days'] as num).toInt(),
      );
    },
  );

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

/// A habit's row as a reset saw it: its day one (YYYY-MM-DD) and best.
typedef SeenHabitRow = ({String day, int best});

/// [RecoveryRepository.resetDayOne] without the database: [update] writes
/// the values only if the row still has the day one and at most the best
/// it's given (true when it did); [reload] reads the row afresh (null once
/// it's gone). The best kept is the larger of the row's best and the days
/// of the streak that just ended, reset day counted as before.
@visibleForTesting
Future<void> resetDayOneGuarded(
  RecoveryHabit habit, {
  required String today,
  required Future<bool> Function(SeenHabitRow seen, Map<String, Object> values)
  update,
  required Future<SeenHabitRow?> Function() reload,
}) async {
  Map<String, Object> valuesFor(SeenHabitRow seen) {
    final streak = RecoveryHabit(
      id: habit.id,
      name: habit.name,
      dayOne: DateTime.parse(seen.day),
      bestStreakDays: seen.best,
      pledgedToday: habit.pledgedToday,
    ).daysIn;
    return {'day_one': today, 'best_streak_days': math.max(seen.best, streak)};
  }

  final seen = (
    day: habit.dayOne.toIso8601String().substring(0, 10),
    best: habit.bestStreakDays,
  );
  if (await update(seen, valuesFor(seen))) return;
  final fresh = await reload();
  if (fresh == null) return;
  await update(fresh, valuesFor(fresh));
}
