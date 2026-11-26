import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.version,
  });

  final String id;
  final String? title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `updated_at` exactly as the server sent it, so a save can be made
  /// conditional on the row not having changed since (a re-formatted
  /// timestamp could differ in precision and never match).
  final String? version;

  /// What a save checks the row against: [version], or [updatedAt] when
  /// the entry didn't come from the server as is.
  String get baseVersion => version ?? updatedAt.toUtc().toIso8601String();

  factory JournalEntry.fromMap(Map<String, dynamic> map) => JournalEntry(
        id: map['id'] as String,
        title: map['title'] as String?,
        content: map['content'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
        updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
        version: map['updated_at'] as String,
      );
}

/// The entry being saved isn't in the account any more — deleted on
/// another device, say. Nothing was written.
class JournalEntryMissing implements Exception {
  const JournalEntryMissing(this.id);
  final String id;
  @override
  String toString() => 'Journal entry $id no longer exists';
}

/// The entry changed in the account (on another device) after the version
/// this save was based on. Nothing was written; [current] is what's there.
class JournalEntryConflict implements Exception {
  const JournalEntryConflict(this.current);
  final JournalEntry current;
  @override
  String toString() => 'Journal entry ${current.id} changed since it was opened';
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

  /// Saves new words over entry [id].
  ///
  /// With [baseVersion] (the entry's `updated_at` when it was opened) the
  /// save only goes through if nobody changed it since; otherwise it throws
  /// [JournalEntryConflict]. Throws [JournalEntryMissing] when the entry is
  /// gone. An update that matched no row used to report success, and the
  /// words were lost when the editor closed.
  Future<void> update(
    String id, {
    String? title,
    required String content,
    String? baseVersion,
  }) async {
    var query = _client
        .from('journal_entries')
        .update({'title': title, 'content': content}).eq('id', id);
    if (baseVersion != null) query = query.eq('updated_at', baseVersion);
    final rows = await query.select('id');
    if (rows.isNotEmpty) return;
    final current = await _client
        .from('journal_entries')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (current == null) throw JournalEntryMissing(id);
    throw JournalEntryConflict(JournalEntry.fromMap(current));
  }

  Future<void> delete(String id) =>
      _client.from('journal_entries').delete().eq('id', id);
}
