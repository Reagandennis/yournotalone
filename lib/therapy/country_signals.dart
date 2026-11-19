/// What the phone already knows about where someone lives, for their session
/// price: the country of their SIM card (Android), of the phone's time zone
/// (set automatically from where it is), of their App Store or Google Play
/// account, and their region setting. Nothing here asks for a permission.
/// The database decides which to use (`therapy_detect_country()`, migration
/// 0035): the SIM's, then the time zone's, then the store's, then the
/// region's — where the phone is before where the account was opened — and
/// never once they've paid for a session.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../billing/purchases_service.dart';
import '../support/phone_country.dart';
import 'therapy_repository.dart';

class CountrySignals {
  const CountrySignals({
    this.store,
    this.sim,
    this.zone,
    this.region,
    this.platform,
  });

  /// The App Store (three letters, "KEN") or Google Play ("KE") account's
  /// country, from RevenueCat.
  final String? store;

  /// The SIM card's country, else the mobile network's ("KE"). Android only.
  final String? sim;

  /// The country of the phone's time zone ("Africa/Nairobi" → "KE"). An
  /// iPhone has no SIM country to give, so this is where it is.
  final String? zone;

  /// The phone's region setting ("KE"), or the country picked on the
  /// crisis screen.
  final String? region;

  /// 'ios', 'android', 'web' or 'other'.
  final String? platform;

  bool get isEmpty =>
      store == null && sim == null && zone == null && region == null;

  /// [withZone] false leaves the time zone out, for a database without
  /// migration 0035.
  Map<String, String?> toParams({bool withZone = true}) => {
    'p_store': store,
    'p_sim': sim,
    'p_region': region,
    'p_platform': platform,
    if (withZone && zone != null) 'p_zone': zone,
  };

  @override
  String toString() =>
      'CountrySignals(store: $store, sim: $sim, zone: $zone, '
      'region: $region, $platform)';
}

/// Reads [CountrySignals], never failing: anything that can't be read is
/// left out. Takes a few seconds at most.
Future<CountrySignals> readCountrySignals() async {
  final region = _safe(deviceCountry);
  if (kIsWeb) return CountrySignals(region: region, platform: 'web');
  final platform = Platform.isIOS
      ? 'ios'
      : Platform.isAndroid
      ? 'android'
      : 'other';
  final found = await Future.wait([
    _storeCountry(),
    simCountry(),
    timeZoneCountry(),
  ]);
  return CountrySignals(
    store: found[0],
    sim: found[1],
    zone: found[2],
    region: region,
    platform: platform,
  );
}

String? _safe(String? Function() read) {
  try {
    return read();
  } catch (_) {
    return null;
  }
}

String? _code(Object? value) {
  final code = value is String ? value.trim().toUpperCase() : '';
  return RegExp(r'^[A-Z]{2,3}$').hasMatch(code) ? code : null;
}

/// The store account's country, through RevenueCat (already set up for
/// premium): Apple's storefront or Google Play's billing country.
Future<String?> _storeCountry() async {
  if (!PurchasesService.instance.isConfigured) return null;
  try {
    final storefront = await Purchases.storefront.timeout(
      const Duration(seconds: 5),
    );
    return _code(storefront?.countryCode);
  } catch (e) {
    debugPrint('Store country unavailable: $e');
    return null;
  }
}
