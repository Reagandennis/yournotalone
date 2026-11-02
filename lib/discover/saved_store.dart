import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_index.dart';

/// Where saves live on the account (`saved_items`, migration 0025).
abstract class SavedItemsRemote {
  /// The account's saved ids, newest first.
  Future<List<String>> fetch();

  /// [ids] newest first; the order is kept.
  Future<void> add(List<String> ids);

  Future<void> remove(List<String> ids);
}

class SupabaseSavedItems implements SavedItemsRemote {
  const SupabaseSavedItems();

  SupabaseQueryBuilder get _table =>
      Supabase.instance.client.from('saved_items');

  @override
  Future<List<String>> fetch() async {
    final rows = await _table
        .select('item_id')
        .order('saved_at', ascending: false);
    return [for (final row in rows) row['item_id'] as String];
  }

  @override
  Future<void> add(List<String> ids) async {
    if (ids.isEmpty) return;
    // A millisecond apart, newest first, so a batch keeps its order.
    final now = DateTime.now().toUtc();
    await _table.upsert(
      [
        for (var i = 0; i < ids.length; i++)
          {
            'item_id': ids[i],
            'saved_at': now
                .subtract(Duration(milliseconds: i))
                .toIso8601String(),
          },
      ],
      onConflict: 'user_id,item_id',
      ignoreDuplicates: true,
    );
  }

  @override
  Future<void> remove(List<String> ids) async {
    if (ids.isEmpty) return;
    await _table.delete().inFilter('item_id', ids);
  }
}

String? _signedInUserId() {
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null; // Supabase not set up (tests, or a failed start).
  }
}

/// Items someone has hearted, by [ContentItem.id]. A [ValueNotifier] so
/// every heart and the Home "Saved" row stay in step.
///
/// The phone keeps its own copy, so hearts respond at once and work
/// offline; each change also waits in a queue until the account has it.
/// [sync] sends the queue, then takes the account's list as the truth —
/// that's how an item unsaved on one phone disappears from another.
class SavedStore extends ValueNotifier<Set<String>> {
  SavedStore._({SavedItemsRemote? remote, String? Function()? userId})
    : _remote = remote ?? const SupabaseSavedItems(),
      _userId = userId ?? _signedInUserId,
      super(const {});

  static final instance = SavedStore._();

  @visibleForTesting
  factory SavedStore.forTest({
    required SavedItemsRemote remote,
    required String? Function() userId,
  }) => SavedStore._(remote: remote, userId: userId);

  static const _key = 'discover.saved';

  /// Changes the account doesn't have yet: id → `add` or `remove`.
  static const _pendingKey = 'discover.saved.pending';

  /// The account the saves on this phone belong to. Unset on phones that
  /// saved things before saves synced.
  static const _ownerKey = 'discover.saved.owner';

  /// Coming back to the app syncs at most this often.
  static const resumeInterval = Duration(hours: 1);

  final SavedItemsRemote _remote;
  final String? Function() _userId;
  Map<String, String> _pending = {};
  String? _owner;
  bool _loaded = false;
  Future<void>? _running;
  bool _again = false;
  DateTime? _lastSync;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      value = {...?prefs.getStringList(_key)};
      _pending = _decode(prefs.getString(_pendingKey));
      _owner = prefs.getString(_ownerKey);
    } catch (e) {
      debugPrint('Saved items unavailable: $e');
    }
    unawaited(sync());
  }

  bool isSaved(ContentItem item) => value.contains(item.id);

  Future<void> toggle(ContentItem item) async {
    final saving = !isSaved(item);
    // Newest first: the Home "Saved" row shows the latest saves up front.
    value = saving ? {item.id, ...value} : {...value}.difference({item.id});
    _pending[item.id] = saving ? 'add' : 'remove';
    await _persist();
    unawaited(sync());
  }

  /// [sync], unless it ran within [resumeInterval]. For coming back to the
  /// app.
  Future<void> syncIfStale() async {
    final last = _lastSync;
    if (last != null && DateTime.now().difference(last) < resumeInterval) {
      return;
    }
    await sync();
  }

  /// Sends waiting changes, then adopts the account's list. Does nothing
  /// signed out; never throws — on failure the queue waits for next time.
  /// A call while one is running waits for it, then runs once more, so a
  /// heart tapped mid-sync is sent too.
  Future<void> sync() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _syncLoop().whenComplete(() => _running = null);
  }

  Future<void> _syncLoop() async {
    do {
      _again = false;
      await _syncOnce();
    } while (_again);
  }

  Future<void> _syncOnce() async {
    final userId = _userId();
    if (userId == null) return;
    try {
      if (_owner != userId) {
        if (_owner == null) {
          // Saves from before syncing: the first account to sync on this
          // phone gets them, merged with whatever it already has.
          for (final id in value) {
            _pending.putIfAbsent(id, () => 'add');
          }
        } else {
          // Someone else signed in on this phone. The last account's saves
          // are on its account, not this one's.
          value = const {};
          _pending = {};
        }
        _owner = userId;
        await _persist();
      }

      final sending = Map.of(_pending);
      // Adds newest first, in the order they're listed locally.
      await _remote.add([
        for (final id in value)
          if (sending[id] == 'add') id,
        for (final MapEntry(:key, :value) in sending.entries)
          if (value == 'add' && !this.value.contains(key)) key,
      ]);
      await _remote.remove([
        for (final MapEntry(:key, :value) in sending.entries)
          if (value == 'remove') key,
      ]);
      // Only what was sent: a heart tapped mid-sync stays queued.
      sending.forEach((id, op) {
        if (_pending[id] == op) _pending.remove(id);
      });

      final server = await _remote.fetch();
      value = {
        for (final MapEntry(:key, :value) in _pending.entries)
          if (value == 'add') key,
        for (final id in server)
          if (_pending[id] != 'remove') id,
      };
      _lastSync = DateTime.now();
      await _persist();
    } catch (e) {
      debugPrint('Saves sync failed, will retry: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, value.toList());
      await prefs.setString(_pendingKey, jsonEncode(_pending));
      if (_owner case final owner?) await prefs.setString(_ownerKey, owner);
    } catch (e) {
      debugPrint('Couldn\'t save that: $e');
    }
  }

  Map<String, String> _decode(String? raw) {
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  /// The saved items that still exist, newest first.
  List<ContentItem> get items {
    final byId = {for (final item in contentIndex) item.id: item};
    return [
      for (final id in value)
        if (byId[id] != null) byId[id]!,
    ];
  }

  @visibleForTesting
  void reset() {
    _loaded = false;
    _pending = {};
    _owner = null;
    _lastSync = null;
    value = const {};
  }
}
