import 'dart:ui' show PlatformDispatcher;

/// One way to reach a human right now.
class CrisisLine {
  const CrisisLine({
    required this.name,
    required this.detail,
    this.phone,
    this.sms,
    this.url,
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
}

class CrisisRegion {
  const CrisisRegion(this.code, this.label, this.emergency, this.lines);

  /// ISO country code, matched against the device locale.
  final String code;
  final String label;

  /// The general emergency number for the region.
  final String emergency;
  final List<CrisisLine> lines;
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

/// The region to open on, guessed from the device locale. Falls back to the
/// international list, which works from anywhere.
CrisisRegion defaultCrisisRegion() {
  final country = PlatformDispatcher.instance.locale.countryCode;
  for (final region in crisisRegions) {
    if (region.code == country) return region;
  }
  return internationalRegion;
}

/// Digits only, so `tel:` accepts it.
String dialable(String phone) => phone.replaceAll(RegExp(r'[^\d+]'), '');
