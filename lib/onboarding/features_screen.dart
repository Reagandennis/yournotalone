import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import 'checkin_screen.dart';
import 'onboarding_ui.dart';

class _Feature {
  const _Feature(this.icon, this.accent, this.title, this.benefit);

  final IconData icon;
  final Color accent;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) benefit;
}

final _features = [
  _Feature(
    Icons.edit_note_rounded,
    Pillars.red,
    (l10n) => l10n.onboardingFeatureMoodTitle,
    (l10n) => l10n.onboardingFeatureMoodBenefit,
  ),
  _Feature(
    Icons.self_improvement_rounded,
    Pillars.blue,
    (l10n) => l10n.onboardingFeatureMeditationTitle,
    (l10n) => l10n.onboardingFeatureMeditationBenefit,
  ),
  _Feature(
    Icons.graphic_eq_rounded,
    Pillars.yellow,
    (l10n) => l10n.onboardingFeatureSoundsTitle,
    (l10n) => l10n.onboardingFeatureSoundsBenefit,
  ),
  _Feature(
    Icons.insights_rounded,
    Pillars.black,
    (l10n) => l10n.onboardingFeatureInsightsTitle,
    (l10n) => l10n.onboardingFeatureInsightsBenefit,
  ),
  _Feature(
    Icons.healing_rounded,
    Pillars.red,
    (l10n) => l10n.onboardingFeatureRecoveryTitle,
    (l10n) => l10n.onboardingFeatureRecoveryBenefit,
  ),
  _Feature(
    Icons.support_agent_rounded,
    Pillars.blue,
    (l10n) => l10n.onboardingFeatureTherapyTitle,
    (l10n) => l10n.onboardingFeatureTherapyBenefit,
  ),
];

/// Second onboarding screen: what's inside the app and how each piece helps.
class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _card(int index, _Feature feature) {
    final c = context.brand;
    final start = (index * 0.09).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, start + 0.4, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - curved.value)),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c.tint(feature.accent, 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                feature.icon,
                size: 22,
                color: c.accent(feature.accent),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title(context.l10n),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    feature.benefit(context.l10n),
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textMuted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return OnboardingScaffold(
      step: 1,
      bottom: ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CheckinScreen()),
        ),
        child: Text(context.l10n.commonContinue),
      ),
      children: [
        Text(
          context.l10n.onboardingFeaturesTitle,
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
          context.l10n.onboardingFeaturesIntro,
          style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.55),
        ),
        const SizedBox(height: 26),
        for (final (i, f) in _features.indexed) _card(i, f),
      ],
    );
  }
}
