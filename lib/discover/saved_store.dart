import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_index.dart';

/// Items someone has hearted, by [ContentItem.id], kept on this device.
/// A [ValueNotifier] so every heart and the Home "Saved" row stay in step.
class SavedStore extends ValueNotifier<Set<String>> {
  SavedStore._() : super(const {});

  static final instance = SavedStore._();

  static const _key = 'discover.saved';
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      value = {...?prefs.getStringList(_key)};
    } catch (e) {
      debugPrint('Saved items unavailable: $e');
    }
  }

  bool isSaved(ContentItem item) => value.contains(item.id);

  Future<void> toggle(ContentItem item) async {
    // Newest first: the Home row shows the latest saves up front.
    value = isSaved(item)
        ? {...value}.difference({item.id})
        : {item.id, ...value};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, value.toList());
    } catch (e) {
      debugPrint('Couldn\'t save that: $e');
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
    value = const {};
  }
}
