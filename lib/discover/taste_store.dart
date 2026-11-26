/// What this person has told the app about its suggestions, kept on the
/// phone: the items they felt better after (from the close-out question
/// after a session), the ones that left them feeling worse, and the ones
/// they've said are not for them.
///
/// [recommend] reads it, so every on-device suggestion — Home, the health
/// card, the home-screen widget, the nudges — learns from the same
/// answers. The server's ranking for Home already learns from the feelings
/// it's sent; "Not for me" stays on this phone.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../practice/feeling_store.dart';
import '../practice/practice_repository.dart';
import 'content_index.dart';

/// How long "Not for me" keeps an item out of suggestions.
const notForMeFor = Duration(days: 30);

/// Feelings older than this no longer count.
const _feelingsWindow = Duration(days: 90);

/// Dismissing this many items of one kind within [notForMeFor] moves the
/// whole kind down (three sounds turned down: fewer sounds).
const _kindAfter = 3;

@immutable
class Taste {
  const Taste({
    this.helped = const {},
    this.unhelpful = const {},
    this.dismissed = const {},
    this.dismissedKinds = const {},
  });

  static const empty = Taste();

  /// Item ids they felt better after, more often than not.
  final Set<String> helped;

  /// Item ids that left them feeling worse more often than better.
  final Set<String> unhelpful;

  /// Item ids they said are not for them, within [notForMeFor].
  final Set<String> dismissed;

  /// Kinds they've turned down [_kindAfter] or more items of.
  final Set<ContentKind> dismissedKinds;

  bool get isEmpty =>
      helped.isEmpty &&
      unhelpful.isEmpty &&
      dismissed.isEmpty &&
      dismissedKinds.isEmpty;

  /// Added to an item's score in [recommend]: as much as a matching need,
  /// so it decides between items that fit the moment equally, without
  /// pushing in one that doesn't fit.
  double boost(ContentItem item) =>
      (helped.contains(item.id) ? 2.0 : 0) -
      (unhelpful.contains(item.id) ? 2.0 : 0) -
      (dismissedKinds.contains(item.kind) ? 1.5 : 0);

  /// Pure, for tests: from the close-out answers (newest first) and the
  /// "Not for me" taps (item id → when).
  static Taste from({
    required List<FeelingRecord> feelings,
    required Map<String, DateTime> dismissals,
    required DateTime now,
    List<ContentItem>? items,
  }) {
    final byPractice = <String, String>{};
    for (final item in items ?? contentIndex) {
      final kind = practiceKindOf(item.kind);
      if (kind == null) continue;
      byPractice.putIfAbsent('${kind.key}|${practiceSlug(item.id)}', () => item.id);
      // Rows from before slugs held the English title.
      byPractice.putIfAbsent('${kind.key}|${item.title}', () => item.id);
    }
    final net = <String, int>{};
    for (final f in feelings.take(50)) {
      if (now.difference(f.at) > _feelingsWindow) continue;
      final id = byPractice['${f.kind.key}|${f.slug}'];
      if (id == null) continue;
      net[id] = (net[id] ?? 0) + f.feeling.score;
    }

    final active = {
      for (final e in dismissals.entries)
        if (now.difference(e.value) < notForMeFor) e.key,
    };
    final kinds = <ContentKind, int>{};
    for (final item in items ?? contentIndex) {
      if (active.contains(item.id)) {
        kinds[item.kind] = (kinds[item.kind] ?? 0) + 1;
      }
    }
    return Taste(
      helped: {
        for (final e in net.entries)
          if (e.value > 0) e.key,
      },
      unhelpful: {
        for (final e in net.entries)
          if (e.value < 0) e.key,
      },
      dismissed: active,
      dismissedKinds: {
        for (final e in kinds.entries)
          if (e.value >= _kindAfter) e.key,
      },
    );
  }
}

/// The practice kind a content kind is logged as, if it's one that asks
/// how it went.
PracticeKind? practiceKindOf(ContentKind kind) => switch (kind) {
  ContentKind.meditation || ContentKind.recovery => PracticeKind.meditation,
  ContentKind.breathing => PracticeKind.breathing,
  ContentKind.sound => PracticeKind.sound,
  _ => null,
};

class TasteStore extends ChangeNotifier {
  TasteStore._();

  static final instance = TasteStore._();

  /// A personal key (see LocalData.personal).
  static const _key = 'discover.not_for_me';

  Taste _current = Taste.empty;
  Map<String, DateTime> _dismissals = {};

  /// Empty until [load] has run; suggestions then simply don't lean on it.
  Taste get current => _current;

  /// Reads the answers and taps again. Cheap; called on open and after a
  /// close-out answer.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dismissals = _decode(prefs.getString(_key));
      final feelings = await FeelingStore.instance.recent();
      _set(Taste.from(
        feelings: feelings,
        dismissals: _dismissals,
        now: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('Suggestion preferences unavailable: $e');
    }
  }

  Future<void> notForMe(ContentItem item, {required String source}) async {
    Sentry.metrics.count('recommendation.not_for_me', 1, attributes: {
      'kind': SentryAttribute.string(item.kind.name),
      'source': SentryAttribute.string(source),
    });
    _dismissals = {..._dismissals, item.id: DateTime.now()};
    await _save();
  }

  /// Undoes [notForMe], from the snackbar.
  Future<void> undo(ContentItem item) async {
    _dismissals = {..._dismissals}..remove(item.id);
    await _save();
  }

  /// On sign-out: the next person starts with their own.
  void clear() {
    _dismissals = {};
    _set(Taste.empty);
  }

  Future<void> _save() async {
    final now = DateTime.now();
    _dismissals.removeWhere((_, at) => now.difference(at) >= notForMeFor);
    _set(Taste(
      helped: _current.helped,
      unhelpful: _current.unhelpful,
      dismissed: _dismissals.keys.toSet(),
      dismissedKinds: Taste.from(
        feelings: const [],
        dismissals: _dismissals,
        now: now,
      ).dismissedKinds,
    ));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode({
        for (final e in _dismissals.entries) e.key: e.value.toIso8601String(),
      }));
    } catch (e) {
      debugPrint('Couldn\'t keep "Not for me": $e');
    }
  }

  void _set(Taste taste) {
    _current = taste;
    notifyListeners();
  }

  static Map<String, DateTime> _decode(String? raw) {
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: ?DateTime.tryParse(e.value as String),
      };
    } catch (_) {
      return {};
    }
  }
}
