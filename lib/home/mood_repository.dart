import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final since = DateTime.now().subtract(Duration(days: days - 1));
    final rows = await _client
        .from('mood_entries')
        .select('mood_score, entry_date')
        .eq('user_id', userId)
        .gte('entry_date', dateKey(since))
        .order('entry_date', ascending: false);
    return [for (final row in rows) MoodEntry.fromMap(row)];
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
