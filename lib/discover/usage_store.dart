import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_index.dart';

/// What this person reaches for, kept on this device: how often each kind
/// of content is opened (so Home can put their favourites first) and their
/// recent searches. Nothing here leaves the phone, and losing it costs
/// nothing but the ordering.
class UsageStore {
  UsageStore._();

  static final instance = UsageStore._();

  static const _opensKey = 'discover.opens';
  static const _searchesKey = 'discover.recent_searches';
  static const _maxSearches = 6;

  Future<void> recordOpen(ContentKind kind) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final counts = _decode(prefs.getString(_opensKey));
      counts[kind.name] = (counts[kind.name] ?? 0) + 1;
      await prefs.setString(_opensKey, jsonEncode(counts));
    } catch (e) {
      debugPrint('Couldn\'t record a visit: $e');
    }
  }

  /// Opens per kind, by [ContentKind.name].
  Future<Map<String, int>> openCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _decode(prefs.getString(_opensKey));
    } catch (e) {
      debugPrint('Visit counts unavailable: $e');
      return {};
    }
  }

  Map<String, int> _decode(String? raw) {
    if (raw == null) return {};
    try {
      return {
        for (final e in (jsonDecode(raw) as Map<String, dynamic>).entries)
          e.key: (e.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  /// Newest first.
  Future<List<String>> recentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_searchesKey) ?? const [];
    } catch (e) {
      debugPrint('Recent searches unavailable: $e');
      return const [];
    }
  }

  Future<void> recordSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = [
        q,
        for (final s in prefs.getStringList(_searchesKey) ?? const <String>[])
          if (s.toLowerCase() != q.toLowerCase()) s,
      ].take(_maxSearches).toList();
      await prefs.setStringList(_searchesKey, list);
    } catch (e) {
      debugPrint('Couldn\'t save a search: $e');
    }
  }

  Future<void> clearSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchesKey);
    } catch (e) {
      debugPrint('Couldn\'t clear searches: $e');
    }
  }
}
