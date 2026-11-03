/// Crisis helplines by country (design §7a): who to call is a matter of
/// where someone is, not what language their phone is in.
///
/// Every entry here is `verified: false` until a person has checked each
/// number against its official source and rung it (content/HELPLINES.md).
/// Until then a release build shows a country's older entry in
/// [crisisRegions], or the international list, and only builds with drafts
/// on (`l10nDraftsEnabled`) show these, so testers can see them.
///
/// Only numbers known to be the current national ones are listed. A wrong
/// crisis number is worse than none: leave a line out rather than guess.
/// Names are given as each service calls itself; country names are in the
/// country's own language, so someone can find theirs whatever language
/// the app is in.
library;

import 'crisis_resources.dart';

const countryHelplines = <CrisisRegion>[
  // ── Markets the app already serves ─────────────────────────────────
  CrisisRegion(
    'KE',
    'Kenya',
    '999',
    [
      CrisisLine(
        name: 'Befrienders Kenya',
        detail: 'Emotional support, Nairobi. Daily.',
        phone: '+254 722 178 177',
        source: 'https://befrienderskenya.org',
      ),
      CrisisLine(
        name: 'Kenya Red Cross',
        detail: 'Free psychosocial support, 24 hours.',
        phone: '1199',
        source: 'https://www.redcross.or.ke',
      ),
    ],
    emergencySource: 'https://www.nationalpolice.go.ke',
    verified: false,
  ),
  CrisisRegion(
    'GR',
    'Ελλάδα',
    '112',
    [
      CrisisLine(
        name: 'Γραμμή Παρέμβασης για την Αυτοκτονία 1018',
        detail: 'Suicide Help Line, run by Klimaka. 24 hours, in Greek.',
        phone: '1018',
        source: 'https://www.klimaka.org.gr',
      ),
      CrisisLine(
        name: 'Γραμμή Ψυχοκοινωνικής Υποστήριξης 10306',
        detail: 'Psychological support line, Ministry of Health. 24 hours.',
        phone: '10306',
        source: 'https://www.moh.gov.gr',
      ),
      CrisisLine(
        name: 'Χαμόγελο του Παιδιού SOS 1056',
        detail: 'For children and young people, and worried adults. 24 hours.',
        phone: '1056',
        source: 'https://www.hamogelo.gr',
      ),
    ],
    emergencySource: 'https://112.gov.gr',
    verified: false,
  ),
  CrisisRegion(
    'GB',
    'United Kingdom',
    '999',
    [
      CrisisLine(
        name: 'Samaritans',
        detail: 'Free, 24 hours, any problem.',
        phone: '116 123',
        source: 'https://www.samaritans.org',
      ),
      CrisisLine(
        name: 'Shout',
        detail: 'Text support, 24 hours — no call needed.',
        sms: ('85258', 'SHOUT'),
        source: 'https://giveusashout.org',
      ),
    ],
    emergencySource: 'https://www.nhs.uk',
    verified: false,
  ),
  CrisisRegion(
    'US',
    'United States',
    '911',
    [
      CrisisLine(
        name: '988 Suicide & Crisis Lifeline',
        detail: 'Call or text 988. Free, 24 hours.',
        phone: '988',
        sms: ('988', 'HELLO'),
        source: 'https://988lifeline.org',
      ),
      CrisisLine(
        name: 'Crisis Text Line',
        detail: 'Text support, 24 hours.',
        sms: ('741741', 'HOME'),
        source: 'https://www.crisistextline.org',
      ),
    ],
    emergencySource: 'https://www.911.gov',
    verified: false,
  ),

  // ── Europe ─────────────────────────────────────────────────────────
  CrisisRegion(
    'IE',
    'Ireland',
    '112',
    [
      CrisisLine(
        name: 'Samaritans',
        detail: 'Free, 24 hours, any problem.',
        phone: '116 123',
        source: 'https://www.samaritans.org/ireland/',
      ),
      CrisisLine(
        name: 'Pieta',
        detail: 'Suicide and self-harm crisis line. Free, 24 hours.',
        phone: '1800 247 247',
        source: 'https://www.pieta.ie',
      ),
      CrisisLine(
        name: '50808',
        detail: 'Text support, 24 hours — no call needed.',
        sms: ('50808', 'HELLO'),
        source: 'https://text50808.ie',
      ),
    ],
    emergencySource: 'https://www.gov.ie',
    verified: false,
  ),
  CrisisRegion(
    'FR',
    'France',
    '112',
    [
      CrisisLine(
        name: '3114 · Numéro national de prévention du suicide',
        detail:
            'Free, 24 hours, for anyone thinking of suicide or worried '
            'about someone.',
        phone: '3114',
        source: 'https://3114.fr',
      ),
    ],
    emergencySource: 'https://www.service-public.fr',
    verified: false,
  ),
  CrisisRegion(
    'DE',
    'Deutschland',
    '112',
    [
      CrisisLine(
        name: 'TelefonSeelsorge',
        detail:
            'Free, anonymous, 24 hours. Also on 0800 111 0 222 and '
            '116 123.',
        phone: '0800 111 0 111',
        source: 'https://www.telefonseelsorge.de',
      ),
    ],
    emergencySource: 'https://www.112.de',
    verified: false,
  ),
  CrisisRegion(
    'ES',
    'España',
    '112',
    [
      CrisisLine(
        name: '024 · Línea de atención a la conducta suicida',
        detail: 'Free, confidential, 24 hours.',
        phone: '024',
        source: 'https://www.sanidad.gob.es/linea024/',
      ),
    ],
    emergencySource: 'https://www.112.es',
    verified: false,
  ),
  CrisisRegion(
    'BE',
    'België · Belgique',
    '112',
    [
      CrisisLine(
        name: 'Zelfmoordlijn 1813',
        detail: 'In Dutch. Free, anonymous, 24 hours.',
        phone: '1813',
        source: 'https://www.zelfmoord1813.be',
      ),
      CrisisLine(
        name: 'Centre de Prévention du Suicide',
        detail: 'In French. Free, 24 hours.',
        phone: '0800 32 123',
        source: 'https://www.preventionsuicide.be',
      ),
    ],
    emergencySource: 'https://www.112.be',
    verified: false,
  ),
  CrisisRegion(
    'CH',
    'Schweiz · Suisse · Svizzera',
    '112',
    [
      CrisisLine(
        name: 'Die Dargebotene Hand · La Main Tendue · Telefono Amico',
        detail: '143. Anonymous, 24 hours.',
        phone: '143',
        source: 'https://www.143.ch',
      ),
      CrisisLine(
        name: 'Pro Juventute',
        detail: '147. For children and young people, 24 hours.',
        phone: '147',
        source: 'https://www.147.ch',
      ),
    ],
    emergencySource: 'https://www.ch.ch',
    verified: false,
  ),

  // ── The Americas ───────────────────────────────────────────────────
  CrisisRegion(
    'CA',
    'Canada',
    '911',
    [
      CrisisLine(
        name: '9-8-8 Suicide Crisis Helpline',
        detail: 'Call or text 988. English and French, 24 hours.',
        phone: '988',
        sms: ('988', 'HELLO'),
        source: 'https://988.ca',
      ),
      CrisisLine(
        name: 'Kids Help Phone',
        detail: 'For young people, 24 hours. Text CONNECT to 686868.',
        phone: '1-800-668-6868',
        sms: ('686868', 'CONNECT'),
        source: 'https://kidshelpphone.ca',
      ),
    ],
    emergencySource: 'https://www.canada.ca',
    verified: false,
  ),
  CrisisRegion(
    'MX',
    'México',
    '911',
    [
      CrisisLine(
        name: 'Línea de la Vida',
        detail: 'Free, 24 hours.',
        phone: '800 911 2000',
        source: 'https://www.gob.mx/salud/conadic',
      ),
    ],
    emergencySource: 'https://www.gob.mx',
    verified: false,
  ),
  CrisisRegion(
    'AR',
    'Argentina',
    '911',
    [
      CrisisLine(
        name: 'Centro de Asistencia al Suicida',
        detail:
            '135 free from Buenos Aires city and province, 24 hours. '
            'From elsewhere, call (011) 5275-1135.',
        phone: '135',
        source: 'https://www.asistenciaalsuicida.org.ar',
      ),
    ],
    emergencySource: 'https://www.argentina.gob.ar',
    verified: false,
  ),
  // Colombia: emergency number only for now — see content/HELPLINES.md.
  CrisisRegion(
    'CO',
    'Colombia',
    '123',
    [],
    emergencySource: 'https://www.policia.gov.co',
    verified: false,
  ),

  // ── Asia-Pacific ───────────────────────────────────────────────────
  CrisisRegion(
    'SG',
    'Singapore',
    '995',
    [
      CrisisLine(
        name: 'Samaritans of Singapore',
        detail: 'Free, 24 hours.',
        phone: '1767',
        source: 'https://www.sos.org.sg',
      ),
    ],
    emergencySource: 'https://www.scdf.gov.sg',
    verified: false,
  ),
  CrisisRegion(
    'MY',
    'Malaysia',
    '999',
    [
      CrisisLine(
        name: 'Befrienders Kuala Lumpur',
        detail: 'Emotional support, 24 hours.',
        phone: '03-7627 2929',
        source: 'https://www.befrienders.org.my',
      ),
    ],
    emergencySource: 'https://www.malaysia.gov.my',
    verified: false,
  ),
  CrisisRegion(
    'TW',
    '臺灣',
    '119',
    [
      CrisisLine(
        name: '衛福部安心專線 1925',
        detail: 'Ministry of Health and Welfare. Free, 24 hours.',
        phone: '1925',
        source: 'https://www.mohw.gov.tw',
      ),
      CrisisLine(
        name: '生命線 1995',
        detail: 'Lifeline Taiwan, 24 hours.',
        phone: '1995',
        source: 'https://www.life1995.org.tw',
      ),
    ],
    emergencySource: 'https://www.nfa.gov.tw',
    verified: false,
  ),
  CrisisRegion(
    'HK',
    '香港',
    '999',
    [
      CrisisLine(
        name: '香港撒瑪利亞防止自殺會 Samaritan Befrienders Hong Kong',
        detail: 'Cantonese, 24 hours.',
        phone: '2389 2222',
        source: 'https://sbhk.org.hk',
      ),
      CrisisLine(
        name: '撒瑪利亞會 The Samaritans Hong Kong',
        detail: 'Multilingual, 24 hours.',
        phone: '2896 0000',
        source: 'https://samaritans.org.hk',
      ),
    ],
    emergencySource: 'https://www.police.gov.hk',
    verified: false,
  ),
  CrisisRegion(
    'AU',
    'Australia',
    '000',
    [
      CrisisLine(
        name: 'Lifeline',
        detail: 'Crisis support, 24 hours.',
        phone: '13 11 14',
        source: 'https://www.lifeline.org.au',
      ),
      CrisisLine(
        name: 'Beyond Blue',
        detail: 'Anxiety and depression support, 24 hours.',
        phone: '1300 22 4636',
        source: 'https://www.beyondblue.org.au',
      ),
    ],
    emergencySource: 'https://www.triplezero.gov.au',
    verified: false,
  ),
];
