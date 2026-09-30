import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../legal/legal_content.dart';

class _FaqItem {
  const _FaqItem(this.question, this.answer);

  final String question;
  final String answer;
}

class _FaqSection {
  const _FaqSection(this.title, this.items);

  final String title;
  final List<_FaqItem> items;
}

const _sections = [
  _FaqSection('Using the app', [
    _FaqItem(
      'What is Δεν είσαι μόνος?',
      'It\'s Greek for "You\'re not alone" — a wellbeing companion for the '
          'moments between the hard ones. Check in with your mood, keep a '
          'private journal, follow guided meditations and breathing '
          'exercises, unwind with calming sounds, track your recovery, and '
          'reach a licensed therapist when you need one.',
    ),
    _FaqItem(
      'Is the app a substitute for therapy or medical care?',
      'No. The app supports your wellbeing, but it doesn\'t diagnose or '
          'treat anything, and it\'s not emergency care. If you\'re in '
          'crisis or immediate danger, call your local emergency number '
          'right away.',
    ),
    _FaqItem(
      'How do daily reminders work?',
      'Go to Settings → Reminders & notifications to switch on gentle '
          'nudges — a morning check-in, a daily pledge, evening pages, and '
          'a wind-down. You choose the times, and reminders are scheduled '
          'on your phone; they never leave your device.',
    ),
  ]),
  _FaqSection('Premium & billing', [
    _FaqItem(
      'What do I get with Premium?',
      'Every room in the house: the full meditation library, all calming '
          'sounds and breathing exercises, unlimited journaling, and the '
          'complete recovery toolkit. Plans usually start with a free trial '
          '— the price is always shown before you subscribe.',
    ),
    _FaqItem(
      'How do I cancel my subscription?',
      'Subscriptions are billed by Apple or Google, so you cancel in your '
          'App Store or Google Play subscription settings — deleting the '
          'app doesn\'t cancel it. You keep Premium until the end of the '
          'period you\'ve paid for.',
    ),
    _FaqItem(
      'I\'m a subscriber, but the app says I\'m on the Free plan.',
      'Make sure you\'re signed in to the same App Store or Google Play '
          'account you subscribed with, then tap Settings → Restore '
          'purchases. If it still doesn\'t unlock, email us and we\'ll '
          'sort it out.',
    ),
    _FaqItem(
      'Can I get a refund?',
      'Refunds for subscriptions are handled by Apple and Google under '
          'their policies — request one from your App Store purchase '
          'history or the Google Play order history. If you get stuck, '
          'write to us and we\'ll point you the right way.',
    ),
  ]),
  _FaqSection('Therapy sessions', [
    _FaqItem(
      'How do I book a therapy session?',
      'Open Talk to a therapist, tell us what you\'d like to talk about '
          'and when suits you, and send the request. Our care team matches '
          'you with a licensed therapist and a time — usually within a day '
          '— and you\'ll see who and when in the app and by email.',
    ),
    _FaqItem(
      'How much does a session cost, and when do I pay?',
      'Each session is \$20, paid securely in the app when you book — '
          'that\'s what sends your request to our care team, and you get a '
          'receipt by email straight away. No subscription; you book one '
          'session at a time.',
    ),
    _FaqItem(
      'What if I need to cancel or move my session?',
      'You can cancel in the app up to 24 hours before your session and '
          'you\'ll be refunded in full. To move it, reply to your booking '
          'email at least 24 hours before and we\'ll rebook you. A session '
          'cancelled later than that, or one you don\'t join, isn\'t '
          'refunded — your therapist has set that time aside for you. If we '
          'or your therapist have to cancel, you\'re refunded in full.',
    ),
    _FaqItem(
      'How do sessions work?',
      'They\'re private video calls, right in the app. The Join button '
          'appears 10 minutes before the start, and you\'ll need your camera '
          'and microphone. Calls aren\'t recorded.',
    ),
    _FaqItem(
      'Will I be reminded?',
      'Yes. You\'ll get an email and a phone notification when you\'re '
          'matched, if anything changes, and 10 minutes before your session. '
          'Phone notifications can arrive a little later than the emails.',
    ),
    _FaqItem(
      'Can I cancel a session?',
      'Yes. You can cancel a request, or a matched session you haven\'t '
          'paid for, from the same screen. To cancel a paid session, contact '
          'us before it starts and we\'ll refund you.',
    ),
    _FaqItem(
      'Who are the therapists?',
      'Licensed mental-health professionals. Our care team matches you '
          'based on what you share in your request, so you don\'t have to '
          'scroll through directories while you\'re struggling. Once you\'re '
          'matched, you can see their profile — credentials, experience and '
          'what they specialise in.',
    ),
    _FaqItem(
      'Can I rate my session?',
      'Yes — after a session, tap it under Past sessions. Your therapist '
          'never sees your rating on its own, only an average across '
          'several people.',
    ),
  ]),
  _FaqSection('Privacy & your data', [
    _FaqItem(
      'Who can read my journal?',
      'Only you. Your entries are protected by row-level security, which '
          'means only your signed-in account can retrieve them — our team '
          'doesn\'t read them.',
    ),
    _FaqItem(
      'Do you sell my data or show ads?',
      'Never. No ads, no analytics trackers, no data brokers. We collect '
          'only what the app needs to work — the Privacy Policy in '
          'Settings spells out every detail.',
    ),
    _FaqItem(
      'How do I delete my account and data?',
      'Settings → Delete account removes your profile, journal, moods, '
          'recovery data, and therapy sessions permanently. You can also '
          'email us from your registered address and we\'ll do it for '
          'you. Deletion can\'t be undone.',
    ),
  ]),
  _FaqSection('Your account', [
    _FaqItem(
      'How do I change my name or profile photo?',
      'Settings → Edit profile. Tap the photo to take a new one, choose '
          'from your library, or remove it.',
    ),
    _FaqItem(
      'How do I change my password?',
      'Settings → Change password sends a secure reset link to your '
          'email. Follow the link, choose a new password, and log back '
          'in.',
    ),
  ]),
];

/// FAQ: grouped, expandable questions, with a contact card at the end.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: legalContactEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Email address copied.')),
      );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 22, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Brand.textMuted,
        ),
      ),
    );
  }

  Widget _item(_FaqItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: Brand.border, width: 1.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: Brand.textMuted,
        collapsedIconColor: Brand.textMuted,
        title: Text(
          item.question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Brand.ink,
            height: 1.4,
          ),
        ),
        children: [
          Text(
            item.answer,
            style: const TextStyle(
              fontSize: 13,
              color: Brand.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x143764CD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: () => _copyEmail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: 22,
                  color: Brand.blue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Still need help?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Write to us at $legalContactEmail — tap to copy.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Brand.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
              children: [
                const PillarStripe(),
                const SizedBox(height: 14),
                const Text(
                  'Quick answers to the questions we hear most. Tap a '
                  'question to open it.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Brand.textMuted,
                    height: 1.55,
                  ),
                ),
                for (final section in _sections) ...[
                  _sectionLabel(section.title),
                  for (final item in section.items) _item(item),
                ],
                _contactCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
