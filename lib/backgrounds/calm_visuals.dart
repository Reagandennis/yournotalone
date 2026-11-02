import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Calm visuals" in Settings: whether backgrounds move, and which one
/// the person picked for each item. Kept on this device.
///
/// On by default. Off doesn't remove the backgrounds, it holds them still
/// — the same picture someone who asked their phone to reduce motion
/// gets.
class CalmVisualsSetting extends ChangeNotifier {
  CalmVisualsSetting._();

  static final instance = CalmVisualsSetting._();

  static const _enabledKey = 'calmVisuals';
  static const _choicesKey = 'calmVisuals.choices';

  bool _enabled = true;
  Map<String, String> _choices = {};

  bool get enabled => _enabled;

  /// The background picked for [itemId], if any.
  String? choiceFor(String itemId) => _choices[itemId];

  /// Reads the saved settings. Never fatal: without storage backgrounds
  /// move and every item opens with its own.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? true;
      final raw = prefs.getString(_choicesKey);
      _choices = raw == null
          ? {}
          : (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
    } catch (e) {
      debugPrint('Calm visuals setting unavailable: $e');
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } catch (e) {
      debugPrint('Couldn\'t save the calm visuals setting: $e');
    }
  }

  /// Opens [itemId] with [backgroundId] from now on; null goes back to the
  /// item's own.
  Future<void> choose(String itemId, String? backgroundId) async {
    if (backgroundId == null) {
      _choices.remove(itemId);
    } else {
      _choices[itemId] = backgroundId;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_choicesKey, jsonEncode(_choices));
    } catch (e) {
      debugPrint('Couldn\'t save the background choice: $e');
    }
  }

  @visibleForTesting
  void reset() {
    _enabled = true;
    _choices = {};
  }
}
