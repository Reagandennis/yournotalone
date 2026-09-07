import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../therapy/therapy_repository.dart';
import '../support/crisis_screen.dart';
import 'onboarding_ui.dart';
import 'paywall_screen.dart';

/// Shown when the check-in suggests the user needs real support: the app
/// offers sessions with licensed therapists, and their first one is free.
class TherapyOfferScreen extends StatefulWidget {
  const TherapyOfferScreen({super.key, required this.checkin});

  /// The wellbeing check-in answer, saved when onboarding completes.
  final String checkin;

  @override
  State<TherapyOfferScreen> createState() => _TherapyOfferScreenState();
}

class _TherapyOfferScreenState extends State<TherapyOfferScreen> {
  bool _claimed = false;
  bool _loading = false;

  Future<void> _finish({required bool wantsFreeSession}) async {
    setState(() => _loading = true);
    if (wantsFreeSession) {
      try {
        await TherapyRepository().requestSession(
          topic: 'Not sure yet',
          note: 'Claimed the free first session during onboarding '
              '(check-in: ${widget.checkin}).',
        );
      } catch (_) {
        // Not fatal — they can book again from the therapy screen.
      }
    }
    if (!mounted) return;
    // Onboarding finishes on the paywall, for everyone. Sending this branch
    // straight to Home meant the users who said they were struggling — half
    // of all answers — never saw what Premium was.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          checkin: widget.checkin,
          fromOnboarding: true,
          extraData: {'therapy_free_session': wantsFreeSession},
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
    if (_claimed) {
      return OnboardingScaffold(
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AuthSubmitButton(
              label: 'Continue',
              loading: _loading,
              onPressed: () => _finish(wantsFreeSession: true),
            ),
            const SizedBox(height: 14),
            _crisisNote,
          ],
        ),
        children: [
          const SizedBox(height: 30),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0x143764CD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                size: 40,
                color: Brand.blue,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Your free session is saved',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: PillarStripe()),
          const SizedBox(height: 18),
          const Text(
            'We\'ll email you within a day to match you with a licensed '
            'therapist and find a time that works for you. There\'s no '
            'charge and no card needed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.6),
          ),
        ],
      );
    }

    return OnboardingScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _loading
                ? null
                : () => setState(() => _claimed = true),
            child: const Text('Claim my free session'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed:
                _loading ? null : () => _finish(wantsFreeSession: false),
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
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your first session is on us',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'One full session with a licensed therapist, completely '
                      'free — no card needed. See if it feels right for you.',
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
