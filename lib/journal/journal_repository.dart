import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory JournalEntry.fromMap(Map<String, dynamic> map) => JournalEntry(
        id: map['id'] as String,
        title: map['title'] as String?,
        content: map['content'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      );
}

/// How many entries the free plan includes.
const freeJournalEntryLimit = 5;

/// CRUD for the user's journal, backed by the `journal_entries` table
/// (row-level security keeps every user inside their own rows).
class JournalRepository {
  final _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw StateError('Not signed in');
    return id;
  }

  Future<List<JournalEntry>> fetchEntries() async {
    final rows = await _client
        .from('journal_entries')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);
    return [for (final row in rows) JournalEntry.fromMap(row)];
  }

  /// How many entries exist. Cheap enough to call before opening the
  /// editor, and the only way the cap can be enforced from screens that
  /// don't already hold the list.
  Future<int> countEntries() async {
    final rows = await _client
        .from('journal_entries')
        .select('id')
        .eq('user_id', _userId);
    return rows.length;
  }

  Future<void> create({String? title, required String content}) async {
    await _client.from('journal_entries').insert({
      'user_id': _userId,
      'title': title,
      'content': content,
    });
    Sentry.metrics.count('journal.entry_created', 1);
  }

  Future<void> update(String id, {String? title, required String content}) =>
      _client
          .from('journal_entries')
          .update({'title': title, 'content': content}).eq('id', id);

  Future<void> delete(String id) =>
      _client.from('journal_entries').delete().eq('id', id);
}
