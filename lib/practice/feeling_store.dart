import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'practice_repository.dart';

/// How someone felt after a session, compared with when they started.
enum Feeling {
  worse(-1, 'Worse'),
  same(0, 'About the same'),
  better(1, 'Better');

  const Feeling(this.score, this.label);

  /// Stored in the database — never change these.
  final int score;
  final String label;

  static Feeling fromScore(int score) =>
      values.firstWhere((f) => f.score == score, orElse: () => same);
}

class FeelingRecord {
  const FeelingRecord({
    required this.kind,
    required this.slug,
    required this.feeling,
    required this.at,
  });

  final PracticeKind kind;
  final String slug;
  final Feeling feeling;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'kind': kind.key,
    'slug': slug,
    'feeling': feeling.score,
    'at': at.toIso8601String(),
  };

  factory FeelingRecord.fromJson(Map<String, dynamic> json) => FeelingRecord(
    kind: PracticeKind.fromKey(json['kind'] as String),
    slug: json['slug'] as String,
    feeling: Feeling.fromScore((json['feeling'] as num).toInt()),
    at: DateTime.parse(json['at'] as String),
  );
}

/// What the answers add up to.
class FeelingSummary {
  const FeelingSummary({required this.answered, required this.better});

  final int answered;
  final int better;

  /// "You felt better after 8 of your last 10 sessions." Null until there
  /// are enough answers to say anything.
  String? get line => answered < 3
      ? null
      : 'You felt better after $better of your last $answered sessions.';
}

/// Keeps the answers on the device (so they count straight away, offline
/// included) and sends each to `session_feelings` when it can. The
/// device copy is what the app reads; the table is the durable record.
class FeelingStore {
  FeelingStore._();

  static final instance = FeelingStore._();

  static const _key = 'practice.feelings';
  static const _keep = 200;

  Future<void> record({
    required PracticeKind kind,
    required String slug,
    required Feeling feeling,
  }) async {
    final entry = FeelingRecord(
      kind: kind,
      slug: slug,
      feeling: feeling,
      at: DateTime.now(),
    );
    Sentry.metrics.count(
      'session.feeling',
      1,
      attributes: {
        'feeling': SentryAttribute.string(feeling.name),
        'kind': SentryAttribute.string(kind.key),
      },
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = [entry, ...await _read(prefs)].take(_keep).toList();
      await prefs.setString(
        _key,
        jsonEncode([for (final r in list) r.toJson()]),
      );
    } catch (e) {
      debugPrint('Couldn\'t keep the feeling: $e');
    }
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      await client
          .from('session_feelings')
          .insert({'kind': kind.key, 'slug': slug, 'feeling': feeling.score})
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      // Kept on the device either way; the table may not exist yet.
      debugPrint('Feeling not sent: $e');
    }
  }

  Future<List<FeelingRecord>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return [
        for (final r in jsonDecode(raw) as List)
          FeelingRecord.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Newest first.
  Future<List<FeelingRecord>> recent() async {
    try {
      return await _read(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('Feelings unavailable: $e');
      return [];
    }
  }

  /// Over the last [last] answers.
  static FeelingSummary summarise(
    List<FeelingRecord> records, {
    int last = 10,
  }) {
    final window = records.take(last).toList();
    return FeelingSummary(
      answered: window.length,
      better: window.where((r) => r.feeling == Feeling.better).length,
    );
  }

  /// How much each kind of practice tends to help, from -1 to 1, for
  /// kinds with at least three answers. Suggestions lean on this.
  static Map<PracticeKind, double> helpByKind(List<FeelingRecord> records) {
    final scores = <PracticeKind, List<int>>{};
    for (final r in records.take(50)) {
      (scores[r.kind] ??= []).add(r.feeling.score);
    }
    return {
      for (final e in scores.entries)
        if (e.value.length >= 3)
          e.key: e.value.reduce((a, b) => a + b) / e.value.length,
    };
  }
}
