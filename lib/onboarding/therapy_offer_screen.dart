import 'package:flutter/material.dart';

import '../brand.dart';
import '../support/crisis_screen.dart';
import '../therapy/therapy_repository.dart';
import 'onboarding_ui.dart';
import 'paywall_screen.dart';

/// Shown when the check-in suggests the user needs real support: the app
/// offers sessions with licensed therapists. Nothing is booked here — a
/// session is paid for when it's requested, from Talk to a therapist — so
/// this only asks whether they'd like to, and remembers the answer.
class TherapyOfferScreen extends StatefulWidget {
  const TherapyOfferScreen({super.key, required this.checkin});

  /// The wellbeing check-in answer, saved when onboarding completes.
  final String checkin;

  @override
  State<TherapyOfferScreen> createState() => _TherapyOfferScreenState();
}

class _TherapyOfferScreenState extends State<TherapyOfferScreen> {
  bool _loading = false;

  Future<void> _finish({required bool interested}) async {
    setState(() => _loading = true);
    // Onboarding finishes on the paywall, for everyone. Sending this branch
    // straight to Home meant the users who said they were struggling — half
    // of all answers — never saw what Premium was.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          checkin: widget.checkin,
          fromOnboarding: true,
          source: 'onboarding',
          extraData: {'therapy_interested': interested},
        ),
      ),
    );
    if (mounted) setState(() => _loading = false);
  }

  static const _crisisNote = CrisisFooter(
    trailing: ' This app can\'t replace emergency care.',
  );

  @override
  Widget build(BuildContext context) {
    final price = formatPrice(therapySessionPriceCents);
    return OnboardingScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _loading ? null : () => _finish(interested: true),
            child: const Text('I\'d like that'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _loading ? null : () => _finish(interested: false),
            child: const Text('Not right now'),
          ),
          const SizedBox(height: 10),
          _crisisNote,
        ],
      ),
      children: [
        const Text(
          'You don\'t have to do this alone',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const PillarStripe(),
        const SizedBox(height: 16),
        const Text(
          'Some seasons are too heavy to carry with an app alone — and '
          'that\'s exactly why we work with real people. Δεν είσαι μόνος '
          'offers private one-on-one sessions with licensed therapists, '
          'right from here.',
          style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.6),
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0x0F3764CD),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  size: 22,
                  color: Brand.red,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'A real therapist, $price a session',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'One session at a time, no subscription. You pay when '
                      'you book, from Talk to a therapist on your Home '
                      'screen, and our care team matches you within a day.',
                      style: TextStyle(
                        fontSize: 13,
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
      ],
    );
  }
}
