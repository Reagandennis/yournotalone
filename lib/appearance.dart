import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, dark, or following the phone — the person's choice, kept on this
/// device. Following the phone is the default, so the app goes dark at
/// night along with everything else.
class AppearanceSetting extends ValueNotifier<ThemeMode> {
  AppearanceSetting._() : super(ThemeMode.system);

  static final instance = AppearanceSetting._();

  static const _key = 'appearance';

  /// Reads the saved choice. Never fatal: without storage the app simply
  /// follows the phone.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = ThemeMode.values.asNameMap()[prefs.getString(_key)] ??
          ThemeMode.system;
    } catch (e) {
      debugPrint('Appearance setting unavailable: $e');
    }
  }

  Future<void> choose(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (e) {
      debugPrint('Couldn\'t save the appearance setting: $e');
    }
  }
}

/// How each choice is named in Settings.
String appearanceLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'Match my phone',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
