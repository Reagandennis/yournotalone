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

/// What [simCountry] and [networkCountry] read in tests: the SIM's and the
/// network's country, as MainActivity.kt answers them.
@visibleForTesting
({String? sim, String? network})? debugTelephony;

Future<({String? sim, String? network})> _telephonyCountries() async {
  if (_silent) {
    final fake = debugTelephony;
    return (sim: _code(fake?.sim), network: _code(fake?.network));
  }
  if (kIsWeb || !Platform.isAndroid) return (sim: null, network: null);
  try {
    final found = await _telephony
        .invokeMapMethod<String, Object?>('countries')
        .timeout(const Duration(seconds: 2));
    return (sim: _code(found?['sim']), network: _code(found?['network']));
  } catch (e) {
    debugPrint('SIM country unavailable: $e');
    return (sim: null, network: null);
  }
}

/// The SIM's country (where the number is from), else the network's. See
/// MainActivity.kt. Null off Android. For session prices: where someone
/// lives, which a trip abroad doesn't change.
Future<String?> simCountry() async {
  final found = await _telephonyCountries();
  return found.sim ?? found.network;
}

/// The mobile network's country (where the phone is right now), else the
/// SIM's. Null off Android. For the crisis screen: someone roaming needs
/// the emergency number of the country they're in.
Future<String?> networkCountry() async {
  final found = await _telephonyCountries();
  return found.network ?? found.sim;
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
