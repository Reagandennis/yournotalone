import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import 'helplines.dart';

/// One way to reach a human right now.
class CrisisLine {
  const CrisisLine({
    required this.name,
    required this.detail,
    this.phone,
    this.sms,
    this.url,
    this.source,
  });

  final String name;

  /// Hours, languages, who it's for — the thing you need to know before
  /// you dial.
  final String detail;

  /// Dialled as-is. Kept with spaces for reading; stripped before use.
  final String? phone;

  /// (number, what to text) for services that take a message instead of a
  /// call — the only option when speaking isn't safe or possible.
  final (String, String)? sms;

  final String? url;

  /// The official page the number was checked against, for the reviewer
  /// (content/HELPLINES.md). Never shown.
  final String? source;
}

class CrisisRegion {
  const CrisisRegion(
    this.code,
    this.label,
    this.emergency,
    this.lines, {
    this.emergencySource,
    this.verified = true,
  });

  /// ISO country code, matched against the device region.
  final String code;
  final String label;

  /// The general emergency number for the region.
  final String emergency;

  /// May be empty when only the emergency number is known; the screen
  /// then leans on the international list.
  final List<CrisisLine> lines;

  /// Where [emergency] was checked, like [CrisisLine.source].
  final String? emergencySource;

  /// Whether a person has checked every number here against its source.
  /// Unchecked regions are shown only in builds with drafts on.
  final bool verified;
}

/// Somewhere to go from anywhere — used as the fallback region and always
/// offered alongside the local one.
const internationalRegion = CrisisRegion(
  'INT',
  'Anywhere else',
  '112',
  [
    CrisisLine(
      name: 'Find a Helpline',
      detail: 'Free, vetted helplines in over 130 countries.',
      url: 'https://findahelpline.com',
    ),
    CrisisLine(
      name: 'Befrienders Worldwide',
      detail: 'A global network of emotional-support centres.',
      url: 'https://befrienders.org',
    ),
  ],
);

/// Kept deliberately short: a long list is the wrong thing to hand someone
/// in crisis. Each region gets its emergency number, one or two lines that
/// answer, and a text option wherever one exists.
const crisisRegions = [
  CrisisRegion('KE', 'Kenya', '999', [
    CrisisLine(
      name: 'Befrienders Kenya',
      detail: 'Emotional support, Nairobi. Daily.',
      phone: '+254 722 178 177',
    ),
    CrisisLine(
      name: 'Niskize',
      detail: 'Counselling line, 24 hours.',
      phone: '+254 718 227 440',
    ),
    CrisisLine(
      name: 'Kenya Red Cross',
      detail: 'Free psychosocial support, 24 hours.',
      phone: '1199',
    ),
  ]),
  CrisisRegion('GR', 'Greece', '112', [
    CrisisLine(
      name: 'Suicide Help Line',
      detail: 'Klimaka. 24 hours, in Greek.',
      phone: '1018',
    ),
    CrisisLine(
      name: 'Psychological Support Line',
      detail: 'Ministry of Health. 24 hours.',
      phone: '10306',
    ),
    CrisisLine(
      name: 'Child & Adolescent Line',
      detail: 'Hamogelo. 24 hours, for under-18s.',
      phone: '116 111',
    ),
  ]),
  CrisisRegion('GB', 'United Kingdom', '999', [
    CrisisLine(
      name: 'Samaritans',
      detail: 'Free, 24 hours, any problem.',
      phone: '116 123',
    ),
    CrisisLine(
      name: 'Shout',
      detail: 'Text support, 24 hours — no call needed.',
      sms: ('85258', 'SHOUT'),
    ),
  ]),
  CrisisRegion('US', 'United States', '911', [
    CrisisLine(
      name: 'Suicide & Crisis Lifeline',
      detail: 'Call or text 988. Free, 24 hours.',
      phone: '988',
      sms: ('988', 'HELLO'),
    ),
    CrisisLine(
      name: 'Crisis Text Line',
      detail: 'Text support, 24 hours.',
      sms: ('741741', 'HOME'),
    ),
  ]),
  internationalRegion,
];

/// The countries this build can show, one region each, by name, with the
/// international list last: a [countryHelplines] entry once it's verified
/// (or any, with [drafts] on), otherwise the country's entry in
/// [crisisRegions], the list that shipped before them.
List<CrisisRegion> availableCrisisRegions({bool? drafts}) {
  final showDrafts = drafts ?? l10nDraftsEnabled;
  final byCode = <String, CrisisRegion>{
    for (final region in crisisRegions)
      if (region.code != internationalRegion.code) region.code: region,
  };
  for (final region in countryHelplines) {
    if (region.verified || showDrafts) byCode[region.code] = region;
  }
  return [
    ...byCode.values.toList()..sort((a, b) => a.label.compareTo(b.label)),
    internationalRegion,
  ];
}

/// The region for [country] (an ISO code), or the international list when
/// this build has nothing for it.
CrisisRegion crisisRegionFor(String? country, {bool? drafts}) {
  for (final region in availableCrisisRegions(drafts: drafts)) {
    if (region.code == country) return region;
  }
  return internationalRegion;
}

/// The country to show helplines for: the one picked on the crisis screen
/// if any, else the first of the phone's [locales] with a region here.
String? crisisCountry([Iterable<Locale>? locales, bool? drafts]) {
  final chosen = CrisisCountrySetting.instance.value;
  if (chosen != null) return chosen;
  final codes = {
    for (final r in availableCrisisRegions(drafts: drafts)) r.code,
  };
  for (final locale in locales ?? PlatformDispatcher.instance.locales) {
    if (codes.contains(locale.countryCode)) return locale.countryCode;
  }
  return null;
}

/// The region to open on: the country picked on the crisis screen, else
/// the device region. Falls back to the international list, which works
/// from anywhere.
CrisisRegion defaultCrisisRegion() => crisisRegionFor(crisisCountry());

/// The country picked under "Change country" on the crisis screen, or null
/// to follow the phone's region. Kept on this device: someone abroad, or
/// whose phone is set to another country, picks once.
class CrisisCountrySetting extends ValueNotifier<String?> {
  CrisisCountrySetting._() : super(null);

  static final instance = CrisisCountrySetting._();

  static const _key = 'crisis.country';

  /// Reads the saved choice. Never fatal: without storage the phone's
  /// region is used.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(_key);
    } catch (e) {
      debugPrint('Crisis country unavailable: $e');
    }
  }

  /// Saves [code], or null for the phone's region.
  Future<void> choose(String? code) async {
    value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (code == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, code);
      }
    } catch (e) {
      debugPrint('Couldn\'t save the crisis country: $e');
    }
  }
}

/// Digits only, so `tel:` accepts it.
String dialable(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');
