import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../discover/saved_store.dart';
import '../media/download_store.dart';

/// What the app keeps on the phone about the person using it, kept apart
/// for each account that signs in here.
///
/// Several tools keep what someone writes only on the phone: parked
/// worries, the sleep diary, stress check-ins, how a session left them
/// feeling, their recent searches, course progress. Those keys weren't tied
/// to an account, so on a shared phone the next person to sign in saw the
/// last one's — even after the last one deleted their account.
///
/// Rather than change every screen, the person's keys are set aside under
/// their account id when they sign out, and brought back when they sign in
/// again; someone else signing in starts with their own. Settings that
/// belong to the phone (language, appearance, downloads, the crisis
/// country) stay where they are.
class LocalData {
  LocalData._();

  static final instance = LocalData._();

  static const _ownerKey = 'local.owner';
  static const _stashPrefix = 'local.stash.';

  /// Keys (or key prefixes, ending in a dot or underscore) that hold one
  /// person's things.
  static const personal = <String>[
    'cbt.',
    'sleep.',
    'stress.',
    'practice.feelings',
    'discover.recent_searches',
    'discover.last_mood',
    'discover.opens',
    'discover.recommendations',
    'courses.progress',
    'goals',
    'rhythm_goal',
    'rhythm.',
    'reminder_',
    'mood.logged',
    'journal.entry_created',
    'reminder.opened',
  ];

  static bool isPersonal(String key) =>
      !key.startsWith(_stashPrefix) &&
      personal.any(
        (p) => (p.endsWith('.') || p.endsWith('_'))
            ? key.startsWith(p)
            : key == p,
      );

  SharedPreferences? _prefs;

  /// Opens storage once, at start-up, so [signedIn] and [signedOut] can
  /// work on it at once — before the next screen reads anything.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Local data unavailable: $e');
    }
  }

  @visibleForTesting
  void debugUse(SharedPreferences prefs) => _prefs = prefs;

  /// [userId] signed in (or the app opened signed in). Returns whether the
  /// person changed, so things that hold onto local data can reload.
  ///
  /// Synchronous on purpose: SharedPreferences answers from memory and
  /// writes behind, so by the time this returns the next screen reads the
  /// right person's things.
  bool signedIn(String userId) {
    final prefs = _prefs;
    if (prefs == null) return false;
    final owner = prefs.getString(_ownerKey);
    if (owner == userId) return false;
    if (owner != null) {
      // The last person never signed out properly (the app was killed, a
      // session expired): theirs is set aside now.
      _stash(prefs, owner);
    } else if (!_anyStash(prefs)) {
      // Nobody has signed in since this began: what's here is from before,
      // and belongs to whoever uses the app first — almost always the same
      // person.
      prefs.setString(_ownerKey, userId);
      return false;
    }
    _restore(prefs, userId);
    prefs.setString(_ownerKey, userId);
    return true;
  }

  /// The person signed out: their things are set aside under their account.
  void signedOut() {
    final prefs = _prefs;
    if (prefs == null) return;
    final owner = prefs.getString(_ownerKey);
    if (owner == null) return;
    _stash(prefs, owner);
    prefs.remove(_ownerKey);
  }

  /// [userId] deleted their account: nothing of theirs stays on the phone
  /// — including what other stores keep per account under their own keys:
  /// journal drafts, practice sessions waiting to be sent, saved items, and
  /// their downloads.
  void forget(String userId) {
    final prefs = _prefs;
    if (prefs == null) return;
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('$_stashPrefix$userId.')) prefs.remove(key);
      // JournalDrafts: journal.draft.<user>.<entry>.
      if (key.startsWith('journal.draft.$userId.')) prefs.remove(key);
    }
    _forgetPendingPractice(prefs, userId);
    _forgetSaved(prefs, userId);
    unawaited(
      DownloadStore.instance.forgetUser(userId).catchError(
        (Object e) => debugPrint('Couldn\'t remove downloads: $e'),
      ),
    );
    if (prefs.getString(_ownerKey) == userId) {
      for (final key in prefs.getKeys().toList()) {
        if (isPersonal(key)) prefs.remove(key);
      }
      prefs.remove(_ownerKey);
    }
  }

  /// PendingPracticeStore's queue holds every account's unsent sessions.
  static const _pendingPracticeKey = 'practice_pending_sessions';

  static void _forgetPendingPractice(SharedPreferences prefs, String userId) {
    final raw = prefs.getStringList(_pendingPracticeKey);
    if (raw == null) return;
    final kept = [
      for (final item in raw)
        if (!_belongsTo(item, userId)) item,
    ];
    if (kept.length != raw.length) {
      prefs.setStringList(_pendingPracticeKey, kept);
    }
  }

  static bool _belongsTo(String item, String userId) {
    try {
      return (jsonDecode(item) as Map)['user_id'] == userId;
    } catch (_) {
      return false;
    }
  }

  /// SavedStore's hearts, if they're this account's (or from before saves
  /// had an owner, while this account is the one signed in here).
  void _forgetSaved(SharedPreferences prefs, String userId) {
    final owner = prefs.getString('discover.saved.owner');
    final theirs = owner == userId ||
        (owner == null && prefs.getString(_ownerKey) == userId);
    if (!theirs) return;
    for (final key in prefs.getKeys().toList()) {
      if (key == 'discover.saved' || key.startsWith('discover.saved.')) {
        prefs.remove(key);
      }
    }
    SavedStore.instance.forgetLocal();
  }

  bool _anyStash(SharedPreferences prefs) =>
      prefs.getKeys().any((k) => k.startsWith(_stashPrefix));

  void _stash(SharedPreferences prefs, String owner) {
    final into = '$_stashPrefix$owner.';
    // What was set aside before is replaced by what they have now.
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(into)) prefs.remove(key);
    }
    for (final key in prefs.getKeys().toList()) {
      if (!isPersonal(key)) continue;
      _copy(prefs, key, '$into$key');
      prefs.remove(key);
    }
  }

  void _restore(SharedPreferences prefs, String userId) {
    for (final key in prefs.getKeys().toList()) {
      if (isPersonal(key)) prefs.remove(key);
    }
    final from = '$_stashPrefix$userId.';
    for (final key in prefs.getKeys().toList()) {
      if (!key.startsWith(from)) continue;
      _copy(prefs, key, key.substring(from.length));
      prefs.remove(key);
    }
  }

  static void _copy(SharedPreferences prefs, String from, String to) {
    switch (prefs.get(from)) {
      case final String v:
        prefs.setString(to, v);
      case final bool v:
        prefs.setBool(to, v);
      case final int v:
        prefs.setInt(to, v);
      case final double v:
        prefs.setDouble(to, v);
      case final List<Object?> v:
        prefs.setStringList(to, [for (final s in v) '$s']);
      default:
        break;
    }
  }
}
