import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../calendar_days.dart';

/// One saved check-in: which day, and how it went.
class MoodEntry {
  const MoodEntry({required this.date, required this.index});

  /// The user's local calendar date for the check-in.
  final DateTime date;

  /// Index into [MoodRepository.moodKeys] — `mood_score - 1`.
  final int index;

  factory MoodEntry.fromMap(Map<String, dynamic> map) => MoodEntry(
        date: DateTime.parse(map['entry_date'] as String),
        index: (map['mood_score'] as int) - 1,
      );
}

/// How many days in a row up to [now] have a check-in, among [dates]
/// (local calendar dates). Today not being logged yet doesn't break
/// yesterday's run.
int checkInStreak(Iterable<DateTime> dates, DateTime now) {
  final checked = {
    for (final d in dates) DateTime(d.year, d.month, d.day),
  };
  var streak = 0;
  for (var back = 0;; back++) {
    final day = DateTime(now.year, now.month, now.day - back);
    if (!checked.contains(day)) {
      if (back == 0) continue;
      return streak;
    }
    streak++;
  }
}

/// Saves and restores the daily mood check-in, one row per user per day
/// in the `mood_entries` table.
class MoodRepository {
  final _client = Supabase.instance.client;

  /// In UI order — index in this list is `mood_score - 1`.
  static const moodKeys = ['awful', 'low', 'okay', 'good', 'great'];

  /// Calendar dates as the database stores them, in the user's own time
  /// zone — so "today" means the user's today, not UTC's.
  static String dateKey(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }

  String _today() => dateKey(DateTime.now());

  /// Index into [moodKeys] of today's saved mood, or null if none yet.
  Future<int?> fetchTodayMoodIndex() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await _client
        .from('mood_entries')
        .select('mood_score')
        .eq('user_id', userId)
        .eq('entry_date', _today())
        .maybeSingle();
    final score = row?['mood_score'] as int?;
    return score == null ? null : score - 1;
  }

  /// Every check-in from the last [days] days, newest first.
  Future<List<MoodEntry>> fetchHistory({int days = 90}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final since = addCalendarDays(DateTime.now(), -(days - 1));
    final rows = await _client
        .from('mood_entries')
        .select('mood_score, entry_date')
        .eq('user_id', userId)
        .gte('entry_date', dateKey(since))
        .order('entry_date', ascending: false);
    return [for (final row in rows) MoodEntry.fromMap(row)];
  }

  /// The dates of every check-in from the last [days] days, newest first:
  /// lighter than [fetchHistory], for counting a long streak.
  Future<List<DateTime>> fetchCheckInDates({required int days}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final since = addCalendarDays(DateTime.now(), -(days - 1));
    final rows = await _client
        .from('mood_entries')
        .select('entry_date')
        .eq('user_id', userId)
        .gte('entry_date', dateKey(since))
        .order('entry_date', ascending: false);
    return [for (final row in rows) DateTime.parse(row['entry_date'] as String)];
  }

  /// The run of days with a check-in up to today. [recent] is history
  /// already fetched for the last [recentDays] days: when the run reaches
  /// back to its start, older dates are fetched until the run ends inside
  /// what was fetched. (History is fetched 90 days at a time, so streaks
  /// used to stop at 90.)
  Future<int> fetchStreak({
    List<MoodEntry> recent = const [],
    int recentDays = 90,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    var streak = checkInStreak([for (final e in recent) e.date], today);
    var days = recentDays;
    // Ten years is plenty, and keeps a bad answer from looping forever.
    while (streak >= days - 1 && days < 3660) {
      days = days < 400 ? 400 : days * 2;
      streak = checkInStreak(await fetchCheckInDates(days: days), today);
    }
    return streak;
  }

  /// Saves (or replaces) today's mood.
  Future<void> saveMood(int index) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not signed in');
    await _client.from('mood_entries').upsert(
      {
        'user_id': userId,
        'mood': moodKeys[index],
        'mood_score': index + 1,
        'entry_date': _today(),
      },
      onConflict: 'user_id,entry_date',
    );
    Sentry.metrics.count('mood.logged', 1);
  }
}
