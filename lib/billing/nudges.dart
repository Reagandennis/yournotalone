import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One-time upgrade nudges, shown at the moments someone has just shown a
/// habit: a third mood check-in, the free practice sessions used up.
///
/// Each fires once per account per install. A nudge that repeats is a nag,
/// and a nag in a mental-health app is worse than no upsell at all.
abstract final class Nudges {
  static final bool _silent = Platform.environment.containsKey('FLUTTER_TEST');

  static final _prefs = SharedPreferencesAsync();

  /// True the first time [key] is claimed for the signed-in user, false
  /// ever after (and always false when nobody is signed in or storage is
  /// unavailable — the safe direction is to stay quiet).
  static Future<bool> claim(String key) async {
    if (_silent) return false;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;
    final pref = 'nudge_${key}_$userId';
    try {
      if (await _prefs.getBool(pref) ?? false) return false;
      await _prefs.setBool(pref, true);
      return true;
    } catch (e) {
      debugPrint('Nudge state unavailable: $e');
      return false;
    }
  }
}
