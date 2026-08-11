import 'package:supabase_flutter/supabase_flutter.dart';

/// Saves and restores the daily mood check-in, one row per user per day
/// in the `mood_entries` table.
class MoodRepository {
  final _client = Supabase.instance.client;

  /// In UI order — index in this list is `mood_score - 1`.
  static const moodKeys = ['awful', 'low', 'okay', 'good', 'great'];

  /// Local calendar date, so "today" means the user's today.
  String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

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
  }
}
