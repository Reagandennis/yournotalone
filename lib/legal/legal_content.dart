/// The Privacy Policy and Terms of Service shown in-app.
///
/// Written for GDPR (EU), Apple App Store Review Guideline 5.1, and
/// Google Play User Data / Health policies. The same text lives in
/// docs/legal/*.html for hosting — keep both in sync when editing.
library;

const legalEntityName = 'Techgetafrica';
const legalEntityAddress = '179 Runda Drive, Nairobi, Kenya';
const legalContactEmail = 'reaganprezzo@gmail.com';
const legalGoverningCountry = 'Kenya';

const legalLastUpdated = '6 October 2026';

class LegalDoc {
  const LegalDoc({
    required this.title,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String intro;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection(this.heading, this.body);

  final String heading;
  final String body;
}

final privacyPolicy = LegalDoc(
  title: 'Privacy Policy',
  intro:
      'yournotalone ("You\'re not alone") is a mental-wellness app. The '
      'nature of what you share with us — moods, journal entries, recovery '
      'progress — is deeply personal, and we treat it that way. This policy '
      'explains, in plain words, what we collect, why, and the rights you '
      'have over it.\n\n'
      'The short version: we collect only what the app needs to work, we '
      'never sell your data, we run no ads, and we use no advertising or '
      'analytics trackers. Your wellbeing data is processed only with your '
      'explicit consent, and you can delete everything at any time.',
  sections: [
    LegalSection(
      'Who we are',
      '$legalEntityName, $legalEntityAddress, is the data controller '
          'responsible for your personal data under the EU General Data '
          'Protection Regulation (GDPR) and equivalent laws.\n\n'
          'For anything in this policy, contact us at $legalContactEmail.',
    ),
    LegalSection(
      'The data we collect',
      'Account data — your name, email address, and password (stored only '
          'as a secure hash) when you create an account, and a profile '
          'photo if you choose to add one.\n\n'
          'Wellbeing data — data you choose to record in the app: mood '
          'check-ins, journal entries, recovery tracking, your onboarding '
          'wellbeing check-in, and your practice history — the meditation, '
          'breathing and listening sessions you complete. This '
          'is health-related data and is treated as special-category data '
          'under Article 9 GDPR (see the next section).\n\n'
          'Therapy sessions — if you request a therapy session: the topic '
          'you select, your preferred times, and any note you write. Once '
          'you\'re matched: your therapist, the session time, and whether '
          'it has been paid for. Afterwards: the note your therapist writes '
          'for you, and any rating or comment you give. Your therapist can '
          'also rate the session and flag concerns for our care team — '
          'such as a missed session or a worry about your safety.\n\n'
          'Video calls — therapy sessions are live audio and video between '
          'you and your therapist. They are not recorded, and no audio or '
          'video is stored.\n\n'
          'Purchase data — if you subscribe to Premium or pay for a therapy '
          'session, our payments provider processes an anonymous app user '
          'ID, your purchases, and store receipt data. We never see or '
          'store your card or payment details; payment is handled entirely '
          'by Apple or Google.\n\n'
          'Technical data — the minimum needed to run a secure service, '
          'such as authentication tokens and server logs, and a random key '
          'for this installation that lets it collect notifications about '
          'your therapy sessions.\n\n'
          'What we do NOT collect: we run no advertising, no third-party '
          'analytics, and no tracking across other apps or websites. We do '
          'not collect your precise location, contacts, or browsing '
          'history, and we never sell personal data.',
    ),
    LegalSection(
      'Your wellbeing data and explicit consent',
      'Moods, journal entries, recovery progress, and your therapy '
          'requests, session notes and ratings are health-related data. '
          'Under Article 9(2)(a) GDPR we process this '
          'data only with your explicit consent, which you give by choosing '
          'to record it in the app.\n\n'
          'You can withdraw that consent at any time by deleting individual '
          'entries or your whole account, or by emailing '
          '$legalContactEmail. Withdrawing consent doesn\'t affect the '
          'lawfulness of processing before withdrawal.\n\n'
          'Your journal is private to you. Our team does not read your '
          'entries; access is restricted by row-level security so that only '
          'your signed-in account can retrieve them.',
    ),
    LegalSection(
      'Why we process your data (legal bases)',
      'To provide the app — creating your account, syncing your entries '
          'across sessions, showing your history and progress. Legal basis: '
          'performance of a contract (Art. 6(1)(b) GDPR).\n\n'
          'To record your wellbeing data — legal basis: your explicit '
          'consent (Art. 6(1)(a) and 9(2)(a) GDPR).\n\n'
          'To arrange and run the therapy sessions you request — matching '
          'you with a therapist, scheduling, the video call, payment, and '
          'feedback afterwards — legal basis: performance of a contract and '
          'your explicit consent.\n\n'
          'To act on a safety concern a therapist raises — legal basis: '
          'your explicit consent and, where someone\'s life may be at risk, '
          'the protection of vital interests (Art. 6(1)(d) GDPR).\n\n'
          'To manage subscriptions and entitlements — legal basis: '
          'performance of a contract.\n\n'
          'To keep the service secure and prevent abuse — legal basis: our '
          'legitimate interest in protecting the service and its users '
          '(Art. 6(1)(f) GDPR).\n\n'
          'To comply with legal obligations, such as tax and accounting '
          'rules — legal basis: legal obligation (Art. 6(1)(c) GDPR).',
    ),
    LegalSection(
      'Who we share data with',
      'We share data only with the service providers (processors) needed '
          'to run the app, under data-processing agreements:\n\n'
          '•  Supabase — hosts our database, authentication, and file '
          'storage (your account, entries, and profile photo).\n'
          '•  RevenueCat — manages subscriptions and in-app purchases. '
          'Receives an app user ID and store receipt data; never your name '
          'or journal.\n'
          '•  Apple App Store / Google Play — process subscription payments '
          'under their own terms and privacy policies.\n'
          '•  Paystack — processes payments for therapy sessions (card, '
          'mobile money, Apple Pay). Receives your email address and the '
          'payment details you enter on its page; never your journal or '
          'what you discuss in a session.\n'
          '•  LiveKit — carries the audio and video of therapy sessions in '
          'real time. Nothing is recorded or stored.\n'
          '•  Resend — delivers the emails about your therapy requests and '
          'sessions, to you, your therapist and our care team.\n\n'
          'If you request a therapy session, our care team sees your '
          'request, name and email address so they can match you. The '
          'therapist you\'re matched with sees your first name, the topic, '
          'your note and the session time — not your email address — and '
          'meets you in the video call.\n\n'
          'We never sell personal data and never share it with advertisers '
          'or data brokers. We would disclose data to authorities only '
          'where the law requires it.',
    ),
    LegalSection(
      'International transfers',
      'Some of our providers process data outside the European Economic '
          'Area. Where that happens, transfers are protected by an adequacy '
          'decision of the European Commission (including the EU–US Data '
          'Privacy Framework where the provider is certified) or by the '
          'Commission\'s Standard Contractual Clauses.',
    ),
    LegalSection(
      'How long we keep your data',
      'Your account data and everything you record stay until you delete '
          'them or delete your account. When you delete your account, your '
          'profile, photo, journal entries, moods, practice history, recovery '
          'data, and therapy sessions, notes and ratings are permanently '
          'removed from our systems, with '
          'residual copies purged from backups within 30 days.\n\n'
          'Purchase records are kept as long as tax and accounting law '
          'requires. Server logs are kept briefly for security and then '
          'deleted.',
    ),
    LegalSection(
      'Your rights',
      'Wherever you live, and especially under the GDPR, you have the '
          'right to:\n\n'
          '•  Access the personal data we hold about you, and get a copy.\n'
          '•  Correct inaccurate data.\n'
          '•  Delete your data ("right to be forgotten").\n'
          '•  Receive your data in a portable, machine-readable format.\n'
          '•  Restrict or object to certain processing.\n'
          '•  Withdraw consent at any time, without affecting prior '
          'processing.\n\n'
          'To exercise any of these, email $legalContactEmail. We respond '
          'within one month, as the GDPR requires, and we will never treat '
          'you differently for exercising your rights.\n\n'
          'You also have the right to lodge a complaint with your local '
          'data-protection supervisory authority. If you are in the EU or '
          'EEA, that is the authority of the country where you live.',
    ),
    LegalSection(
      'Deleting your account',
      'You can delete your account and all associated data at any time '
          'from Settings → Delete account inside the app, or by emailing '
          '$legalContactEmail from your registered address. Deletion is '
          'permanent and cannot be undone.',
    ),
    LegalSection(
      'Security',
      'All data travels encrypted (TLS) and is stored encrypted at rest. '
          'Access to your entries is enforced by row-level security tied '
          'to your account. Passwords are stored only as secure hashes. No '
          'system is perfectly secure, but if a breach ever affects your '
          'data we will notify you and the supervisory authority as the '
          'GDPR requires.',
    ),
    LegalSection(
      'Children',
      'The app is not directed to children and is not intended for anyone '
          'under 16. We do not knowingly collect data from children under '
          '16; if you believe a child has created an account, contact us '
          'and we will delete it.',
    ),
    LegalSection(
      'Changes to this policy',
      'If we change this policy in a way that matters, we will tell you '
          'in the app before the change takes effect and, where the change '
          'concerns your wellbeing data, ask for your consent again. The '
          '"last updated" date at the top always reflects the current '
          'version.',
    ),
    LegalSection(
      'Contact',
      '$legalEntityName\n$legalEntityAddress\n$legalContactEmail',
    ),
  ],
);

final termsOfService = LegalDoc(
  title: 'Terms of Service',
  intro:
      'These terms are the agreement between you and $legalEntityName '
      '("we", "us") for using yournotalone ("You\'re not alone", the '
      '"app"). By creating an account or using the app you agree to them. '
      'Please also read our Privacy Policy — it explains how we handle '
      'your data and is part of this agreement.',
  sections: [
    LegalSection(
      'What the app is — and what it isn\'t',
      'The app offers wellbeing tools: mood tracking, journaling, guided '
          'meditations, breathing exercises, calming sounds, recovery '
          'tracking, reminders, and video sessions with licensed '
          'therapists.\n\n'
          'The app is NOT a medical device, does not provide medical '
          'advice, diagnosis, or treatment, and is not a substitute for '
          'professional care. Content in the app is for wellbeing support '
          'only.\n\n'
          'If you are in crisis or immediate danger, do not rely on the '
          'app — call your local emergency number right away.',
    ),
    LegalSection(
      'Who can use the app',
      'You must be at least 16 years old and legally able to enter into '
          'this agreement. If you are under 18, use the app only with the '
          'involvement of a parent or guardian.',
    ),
    LegalSection(
      'Your account',
      'Keep your login details safe — you are responsible for activity '
          'on your account. Give us accurate information and keep it up to '
          'date. You can delete your account at any time from Settings → '
          'Delete account; deletion is permanent.',
    ),
    LegalSection(
      'Premium subscriptions',
      'Some features require a paid Premium subscription, billed through '
          'your Apple App Store or Google Play account — never directly by '
          'us.\n\n'
          '•  Prices, billing period, and any introductory offer are shown '
          'in the app before you subscribe.\n'
          '•  Subscriptions renew automatically at the end of each period '
          'unless you cancel at least 24 hours before renewal.\n'
          '•  Cancel anytime in your App Store or Google Play subscription '
          'settings; you keep access until the end of the paid period.\n'
          '•  Introductory offers (like a free trial) apply once per '
          'account. When the offer ends, the subscription continues at the '
          'standard price unless you cancel before then.\n'
          '•  Refunds are handled by Apple or Google under their policies. '
          'EU consumers: by starting the subscription immediately, you '
          'consent to immediate performance and acknowledge that the '
          '14-day right of withdrawal is lost once the digital service has '
          'been fully performed; where it applies, request refunds through '
          'the store you purchased from.\n\n'
          'If we change subscription prices, the change applies only from '
          'your next renewal, and you will be notified in advance with the '
          'chance to cancel.',
    ),
    LegalSection(
      'Therapy sessions',
      'The app lets you request a session with a licensed therapist. Our '
          'care team matches you with a therapist and a time, which you see '
          'in the app and by email. Sessions are private video calls inside '
          'the app and are not recorded. They are delivered by licensed '
          'professionals responsible for their own clinical practice.\n\n'
          '•  Each session costs US\$20 (or the local-currency price the '
          'store shows you), paid in the app when you request it. Your '
          'request reaches our care team only once it\'s paid for, and we '
          'email you a receipt.\n'
          '•  You can cancel in the app at any time before you\'re matched, '
          'and up to 24 hours before a booked session starts; either way '
          'you\'re refunded in full. To move a booked session, contact us '
          'at least 24 hours before it starts.\n'
          '•  A session cancelled with less than 24 hours\' notice, or one '
          'you don\'t join, is not refunded: your therapist has set that '
          'time aside for you. We\'ll tell you by email and in the app when '
          'a session is closed as missed.\n'
          '•  If we or your therapist cancel a session, we\'ll refund it in '
          'full.\n'
          '•  After a session you can rate it, and your therapist can give '
          'feedback about it to our care team.\n\n'
          'Therapy arranged through the app is not emergency care.',
    ),
    LegalSection(
      'Your content',
      'What you write and upload — journal entries, moods, your profile '
          'photo — remains yours. You give us only the limited licence '
          'needed to store, process, and display that content back to you, '
          'which is what running the app requires. We claim no other '
          'rights over it.\n\n'
          'You are responsible for what you upload. Don\'t upload a '
          'profile photo you don\'t have the right to use, or content '
          'that is unlawful.',
    ),
    LegalSection(
      'Acceptable use',
      'Don\'t misuse the app. In particular, don\'t:\n\n'
          '•  break the law or infringe others\' rights through the app;\n'
          '•  attempt to access other users\' data or probe, disable, or '
          'disrupt our systems;\n'
          '•  reverse-engineer, copy, or resell the app or its content;\n'
          '•  record, screenshot, or share a therapy session without the '
          'other person\'s consent;\n'
          '•  use the app to harm yourself or others — if you are at '
          'risk, please seek professional or emergency help.',
    ),
    LegalSection(
      'Intellectual property',
      'The app, its design, branding, meditations, sounds, and other '
          'content belong to us or our licensors. Your subscription gives '
          'you a personal, non-transferable right to use them within the '
          'app, and nothing more.',
    ),
    LegalSection(
      'Ending the agreement',
      'You can stop using the app or delete your account at any time. We '
          'may suspend or close accounts that seriously or repeatedly '
          'break these terms, after warning you where reasonable. If we '
          'ever discontinue the app, we will give you reasonable notice so '
          'you can export your data.',
    ),
    LegalSection(
      'Liability',
      'We provide the app with reasonable skill and care. To the extent '
          'permitted by law, we are not liable for indirect or '
          'unforeseeable losses, or for issues caused by events outside '
          'our reasonable control.\n\n'
          'Nothing in these terms excludes or limits liability that '
          'cannot legally be excluded — including liability for death or '
          'personal injury caused by negligence, for gross negligence or '
          'wilful misconduct, or your statutory rights as a consumer, '
          'including EU rules on the conformity of digital content and '
          'services.',
    ),
    LegalSection(
      'Governing law and disputes',
      'These terms are governed by the laws of $legalGoverningCountry. If '
          'you are a consumer in the EU or EEA, you also keep the '
          'protection of the mandatory consumer laws of the country where '
          'you live, and you may bring disputes before the courts of that '
          'country.\n\n'
          'If something goes wrong, contact us first at '
          '$legalContactEmail — most issues can be sorted out directly.',
    ),
    LegalSection(
      'Changes to these terms',
      'If we make material changes to these terms, we will notify you in '
          'the app before they take effect. If you don\'t agree with a '
          'change, you can stop using the app and delete your account; '
          'continuing to use the app after the change means you accept it.',
    ),
    LegalSection(
      'Contact',
      '$legalEntityName\n$legalEntityAddress\n$legalContactEmail',
    ),
  ],
);
