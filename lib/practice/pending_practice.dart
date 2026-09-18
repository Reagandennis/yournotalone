import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'practice_repository.dart';

/// A finished session that hasn't reached the server yet.
///
/// Carries its own row id and completion time, so a retry after a lost
/// response can't record the session twice (the id is the primary key) and
/// a session synced days later still lands on the day it happened.
class PendingPracticeSession {
  const PendingPracticeSession({
    required this.id,
    required this.userId,
    required this.kind,
    required this.slug,
    required this.title,
    required this.minutes,
    required this.completedAt,
  });

  final String id;
  final String userId;
  final PracticeKind kind;
  final String slug;
  final String title;
  final double minutes;
  final DateTime completedAt;

  factory PendingPracticeSession.fromJson(Map<String, dynamic> json) =>
      PendingPracticeSession(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        kind: PracticeKind.fromKey(json['kind'] as String),
        slug: json['slug'] as String,
        title: json['title'] as String,
        minutes: (json['minutes'] as num).toDouble(),
        completedAt: DateTime.parse(json['completed_at'] as String),
      );

  /// Also the row sent to `practice_sessions`.
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'kind': kind.key,
        'slug': slug,
        'title': title,
        'minutes': minutes,
        'completed_at': completedAt.toUtc().toIso8601String(),
      };

  PracticeSession toSession() => PracticeSession(
        kind: kind,
        slug: slug,
        title: title,
        minutes: minutes,
        completedAt: completedAt.toLocal(),
      );
}

/// Sessions waiting to be written, kept on the device across launches.
///
/// Small and rarely more than a handful of entries, so a JSON list in
/// SharedPreferences is enough; reads and writes are local and quick.
class PendingPracticeStore {
  static const _key = 'practice_pending_sessions';

  Future<List<PendingPracticeSession>> all() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      return [
        for (final item in raw)
          PendingPracticeSession.fromJson(
              Map<String, dynamic>.from(jsonDecode(item) as Map)),
      ];
    } catch (e) {
      debugPrint('Pending practice store unreadable: $e');
      return const [];
    }
  }

  Future<void> add(PendingPracticeSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = <String>[...?prefs.getStringList(_key)];
    raw.add(jsonEncode(session.toJson()));
    await prefs.setStringList(_key, raw);
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final kept = [
      for (final item in raw)
        if ((jsonDecode(item) as Map)['id'] != id) item,
    ];
    if (kept.length != raw.length) await prefs.setStringList(_key, kept);
  }
}
