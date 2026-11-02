import 'package:flutter/material.dart';

import '../brand.dart';
import '../discover/content_index.dart';
import '../discover/content_widgets.dart';
import '../discover/goals.dart';
import '../l10n/l10n.dart';
import 'onboarding_ui.dart';
import 'paywall_screen.dart';
import 'therapy_offer_screen.dart';

class _CheckinOption {
  const _CheckinOption(this.key, this.icon, this.label, this.detail,
      {this.needsSupport = false});

  final String key;
  final IconData icon;
  final String Function(AppLocalizations l10n) label;
  final String Function(AppLocalizations l10n) detail;

  /// True for answers that should lead to the human-therapy offer.
  final bool needsSupport;
}

final _options = [
  _CheckinOption(
    'steady',
    Icons.sentiment_satisfied_alt_rounded,
    (l10n) => l10n.onboardingCheckinSteady,
    (l10n) => l10n.onboardingCheckinSteadyDetail,
  ),
  _CheckinOption(
    'stressed',
    Icons.sentiment_neutral_rounded,
    (l10n) => l10n.onboardingCheckinStressed,
    (l10n) => l10n.onboardingCheckinStressedDetail,
  ),
  _CheckinOption(
    'struggling',
    Icons.sentiment_dissatisfied_rounded,
    (l10n) => l10n.onboardingCheckinStruggling,
    (l10n) => l10n.onboardingCheckinStrugglingDetail,
    needsSupport: true,
  ),
  _CheckinOption(
    'dark_place',
    Icons.sentiment_very_dissatisfied_rounded,
    (l10n) => l10n.onboardingCheckinDarkPlace,
    (l10n) => l10n.onboardingCheckinDarkPlaceDetail,
    needsSupport: true,
  ),
];

/// Third onboarding step — the wellbeing check-in. The answer decides
/// whether we lead with human therapy or with the premium offer.
class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  _CheckinOption? _selected;
  final _goals = <Need>{};

  void _continue() {
    final choice = _selected;
    if (choice == null) return;
    // Shapes Home's suggestions and Explore's order from the first visit.
    if (_goals.isNotEmpty) {
      saveOnboardingAnswers({goalKey: [for (final g in _goals) g.name]});
    }
    final next = choice.needsSupport
        ? TherapyOfferScreen(checkin: choice.key)
        : PaywallScreen(
            checkin: choice.key,
            fromOnboarding: true,
            source: 'onboarding',
          );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => next));
  }

  Widget _optionCard(_CheckinOption option) {
    final c = context.brand;
    final selected = option == _selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? c.tint(Pillars.black, 0.04) : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? c.ink : c.border,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _selected = option),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 26,
                  color: selected ? c.ink : c.textMuted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label(context.l10n),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.detail(context.l10n),
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return OnboardingScaffold(
      step: 2,
      bottom: ElevatedButton(
        onPressed: _selected == null ? null : _continue,
        child: Text(context.l10n.commonContinue),
      ),
      children: [
        Text(
          context.l10n.onboardingCheckinTitle,
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
          context.l10n.onboardingCheckinIntro,
          style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.55),
        ),
        const SizedBox(height: 26),
        for (final option in _options) _optionCard(option),
        const SizedBox(height: 18),
        Text(
          context.l10n.onboardingGoalsTitle,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.onboardingGoalsHint,
          style: TextStyle(fontSize: 13, color: c.textMuted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final need in goalChoices)
              FilterPill(
                label: need.label,
                icon: need.icon,
                color: need.color,
                selected: _goals.contains(need),
                onTap: () => setState(() {
                  if (!_goals.remove(need)) _goals.add(need);
                }),
              ),
          ],
        ),
      ],
    );
  }
}
