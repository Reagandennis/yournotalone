import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Journal writing that hasn't reached the account yet.
class JournalDraft {
  const JournalDraft({required this.title, required this.content, this.base});

  final String title;
  final String content;

  /// For a draft of an existing entry: that entry's `updated_at` when the
  /// draft was started from it. If the entry has changed since (on another
  /// device), the draft is older than what's saved and mustn't silently
  /// replace it. Null for a new entry, and for drafts kept before this was
  /// recorded.
  final String? base;

  factory JournalDraft.fromJson(Map<String, dynamic> json) => JournalDraft(
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        base: json['base'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        if (base != null) 'base': base,
      };
}

String? _signedInUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null; // Supabase not set up (tests, or a failed start).
  }
}

/// Unsaved journal writing, kept on the phone so a closed app, a dead
/// battery or a save that failed offline doesn't take the entry with it.
///
/// One draft per entry — a new entry has its own, and editing an entry
/// never turns up another one's draft — and per account, so someone else
/// signing in on the same phone never finds another person's writing.
class JournalDrafts {
  JournalDrafts({String? Function()? userId})
      : _userId = userId ?? _signedInUserId;

  final String? Function() _userId;

  /// Null when nobody is signed in: nothing can be saved then anyway, and
  /// a draft with no owner could turn up for whoever signs in next.
  String? _key(String? entryId) {
    final user = _userId();
    if (user == null) return null;
    return 'journal.draft.$user.${entryId ?? 'new'}';
  }

  /// The draft for [entryId], or for a new entry when it's null.
  Future<JournalDraft?> load(String? entryId) async {
    final key = _key(entryId);
    if (key == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return JournalDraft.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (e) {
      debugPrint('Journal draft unreadable: $e');
      return null;
    }
  }

  Future<void> save(String? entryId, JournalDraft draft) async {
    final key = _key(entryId);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(draft.toJson()));
  }

  Future<void> clear(String? entryId) async {
    final key = _key(entryId);
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
