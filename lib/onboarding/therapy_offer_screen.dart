import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../support/crisis_screen.dart';
import '../therapy/therapy_repository.dart';
import 'onboarding_ui.dart';
import 'paywall_screen.dart';

/// Shown when the check-in suggests the user needs real support: the app
/// offers sessions with licensed therapists. Nothing is booked here — a
/// session is paid for when it's requested, from Talk to a therapist — so
/// this only asks whether they'd like to, and remembers the answer.
class TherapyOfferScreen extends StatefulWidget {
  const TherapyOfferScreen({
    super.key,
    required this.checkin,
    this.repository,
  });

  /// The wellbeing check-in answer, saved when onboarding completes.
  final String checkin;

  /// Where the session price comes from; injectable for tests.
  final TherapyRepository? repository;

  @override
  State<TherapyOfferScreen> createState() => _TherapyOfferScreenState();
}

class _TherapyOfferScreenState extends State<TherapyOfferScreen> {
  bool _loading = false;

  /// The price for their country; null while it loads, and the card's
  /// title waits for it rather than showing one price and then another.
  TherapyPriceQuote? _quote;

  @override
  void initState() {
    super.initState();
    final repository = widget.repository ?? TherapyRepository();
    loadTherapyPriceQuote(repository).then((quote) {
      if (mounted) setState(() => _quote = quote);
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final price = (_quote ?? TherapyPriceQuote.fallback).priceLabel;
    return OnboardingScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _loading ? null : () => _finish(interested: true),
            child: Text(l10n.onboardingTherapyYes),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _loading ? null : () => _finish(interested: false),
            child: Text(l10n.onboardingTherapyNo),
          ),
          const SizedBox(height: 10),
          CrisisFooter(trailing: l10n.onboardingTherapyCrisisTrailing),
        ],
      ),
      children: [
        Text(
          l10n.onboardingTherapyTitle,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: c.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const PillarStripe(),
        const SizedBox(height: 16),
        Text(
          l10n.onboardingTherapyIntro,
          style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.6),
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.tint(Pillars.blue, 0.06),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.chip,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 22,
                  color: c.red,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedOpacity(
                      opacity: _quote == null ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        l10n.onboardingTherapyPrice(price),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.onboardingTherapyHowItWorks,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textMuted,
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
