/// Where the phone is, as a country, without asking for a permission or
/// reading its location: the SIM card's country (Android) and the country
/// of its time zone, which phones set from where they are. For session
/// prices (lib/therapy/country_signals.dart) and for which helplines the
/// crisis screen opens on.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import 'zone_countries.dart';

/// Widget tests have no plugins to answer (the time zone's never would).
final bool _silent = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

/// What [timeZoneCountry] reads in tests, as an IANA name.
@visibleForTesting
String? debugTimeZone;

String? _code(Object? value) {
  final code = value is String ? value.trim().toUpperCase() : '';
  return RegExp(r'^[A-Z]{2,3}$').hasMatch(code) ? code : null;
}

const _telephony = MethodChannel('yournotalone/telephony');

/// The SIM's country (where the number is from), else the network's. See
/// MainActivity.kt. Null off Android.
Future<String?> simCountry() async {
  if (kIsWeb || _silent || !Platform.isAndroid) return null;
  try {
    final found = await _telephony
        .invokeMapMethod<String, Object?>('countries')
        .timeout(const Duration(seconds: 2));
    return _code(found?['sim']) ?? _code(found?['network']);
  } catch (e) {
    debugPrint('SIM country unavailable: $e');
    return null;
  }
}

/// The country of the phone's time zone, which phones set from where they
/// are unless someone has turned that off. Null when the zone isn't one
/// country's (UTC) or can't be read.
Future<String?> timeZoneCountry() async {
  if (_silent) return zoneCountries[debugTimeZone];
  try {
    final info = await FlutterTimezone.getLocalTimezone().timeout(
      const Duration(seconds: 2),
    );
    return zoneCountries[info.identifier];
  } catch (e) {
    debugPrint('Time zone unavailable: $e');
    return null;
  }
}
