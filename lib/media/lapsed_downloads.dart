import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../discover/content_index.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
import 'download_store.dart';
import 'download_strings.dart';

/// Premium downloads after Premium ends (docs/backend-design.md §6).
///
/// The files stay on the phone, and opening one shows the upgrade sheet
/// like any locked item. Once the subscription has been inactive for
/// [lapse], the person is asked, once, whether to remove them to free up
/// space. "Keep" stops the question for another [lapse]. Nothing is ever
/// deleted without that answer.
///
/// "Inactive for 30 days" is measured from the last time this phone saw
/// premium active, kept in SharedPreferences: neither RevenueCat's cache
/// nor the comp flag says when premium ended.
class LapsedDownloads {
  LapsedDownloads({
    DateTime Function()? clock,
    DownloadStore? store,
    bool Function()? premium,
    bool Function(String itemId)? isPremiumItem,
  }) : _clock = clock ?? DateTime.now,
       // Looked up each time, so a test's replacement instance is used.
       _store = store == null ? (() => DownloadStore.instance) : (() => store),
       _premium = premium ?? isPremiumUser,
       _isPremiumItem = isPremiumItem ?? _premiumInIndex;

  /// Replaceable so tests can use a fake clock and store.
  static LapsedDownloads instance = LapsedDownloads();

  static const lapse = Duration(days: 30);

  static const _seenKey = 'media.premium.lastSeen';
  static const _askAfterKey = 'media.downloads.lapsedAskAfter';

  final DateTime Function() _clock;
  final DownloadStore Function() _store;
  final bool Function() _premium;
  final bool Function(String itemId) _isPremiumItem;

  /// True while the dialog is up, so a resume can't open a second one.
  bool _asking = false;

  DownloadStore get _downloads => _store();

  static bool _premiumInIndex(String itemId) {
    for (final item in contentIndex) {
      if (item.id == itemId) return item.premium;
    }
    // Not in this build's catalogue: nothing says it's premium, so keep it.
    return false;
  }

  /// Notes that premium is active now. Never throws.
  Future<void> notePremium() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seenKey, _clock().toUtc().toIso8601String());
      // A new lapse starts the count afresh.
      await prefs.remove(_askAfterKey);
    } catch (e) {
      debugPrint('Couldn\'t note premium: $e');
    }
  }

  /// Finished downloads of premium items: their ids and total size.
  Future<(List<String>, int)> premiumDownloads() async {
    await _downloads.load();
    final ids = <String>[];
    var bytes = 0;
    for (final (id, state) in _downloads.downloaded) {
      if (!_isPremiumItem(id)) continue;
      ids.add(id);
      bytes += state.bytes;
    }
    return (ids, bytes);
  }

  /// The size of premium downloads to offer to remove, or null when it's
  /// not time to ask: premium is active, there are none, premium was seen
  /// less than [lapse] ago, or "Keep" was picked less than [lapse] ago.
  Future<int?> due() async {
    if (_premium()) {
      await notePremium();
      return null;
    }
    final (ids, bytes) = await premiumDownloads();
    if (ids.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = _clock();
      final seen = DateTime.tryParse(prefs.getString(_seenKey) ?? '');
      if (seen == null) {
        // Downloaded before the app kept this: start counting now rather
        // than ask straight away.
        await prefs.setString(_seenKey, now.toUtc().toIso8601String());
        return null;
      }
      if (now.difference(seen) < lapse) return null;
      final askAfter = DateTime.tryParse(prefs.getString(_askAfterKey) ?? '');
      if (askAfter != null && now.isBefore(askAfter)) return null;
      return bytes;
    } catch (e) {
      debugPrint('Couldn\'t check lapsed downloads: $e');
      return null;
    }
  }

  /// "Keep": not again for another [lapse].
  Future<void> keep() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _askAfterKey,
        _clock().add(lapse).toUtc().toIso8601String(),
      );
    } catch (e) {
      debugPrint('Couldn\'t save the answer: $e');
    }
  }

  /// "Remove": deletes every premium download. Free ones stay.
  Future<void> remove() async {
    final (ids, _) = await premiumDownloads();
    for (final id in ids) {
      await _downloads.remove(id);
    }
  }

  /// Asks if it's time ([due]). Safe to call on every launch and resume.
  Future<void> maybeAsk(BuildContext context) async {
    if (_asking) return;
    _asking = true;
    try {
      final bytes = await due();
      if (bytes == null || !context.mounted) return;
      final l10n = context.l10n;
      final remove = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.downloadsLapsedTitle),
          content: Text(l10n.downloadsLapsedBody(formatBytes(bytes))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.downloadsLapsedKeep),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.downloadsLapsedRemove),
            ),
          ],
        ),
      );
      // Dismissed without an answer counts as "Keep": never delete
      // unasked, and don't ask again tomorrow.
      if (remove == true) {
        await this.remove();
      } else {
        await keep();
      }
    } finally {
      _asking = false;
    }
  }
}
