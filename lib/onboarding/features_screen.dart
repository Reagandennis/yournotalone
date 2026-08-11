import 'package:flutter/material.dart';

import '../brand.dart';
import 'checkin_screen.dart';
import 'onboarding_ui.dart';

class _Feature {
  const _Feature(this.icon, this.accent, this.title, this.benefit);

  final IconData icon;
  final Color accent;
  final String title;
  final String benefit;
}

const _features = [
  _Feature(
    Icons.edit_note_rounded,
    Brand.red,
    'Mood tracking & journaling',
    'Check in with yourself daily and put feelings into words, in a space '
        'that\'s completely private.',
  ),
  _Feature(
    Icons.self_improvement_rounded,
    Brand.blue,
    'Guided meditations & breathing',
    'Short guided sessions that steady your breath and quiet a racing mind.',
  ),
  _Feature(
    Icons.graphic_eq_rounded,
    Brand.yellow,
    'Wellbeing sounds',
    'Soundscapes for focus, sleep, and calming down — whenever you need '
        'to reset.',
  ),
  _Feature(
    Icons.insights_rounded,
    Brand.ink,
    'Progress insights & reminders',
    'See your patterns over time and get gentle nudges that keep you going.',
  ),
  _Feature(
    Icons.healing_rounded,
    Brand.red,
    'Addiction recovery tools',
    'Practical resources for fighting addiction — one day at a time.',
  ),
  _Feature(
    Icons.support_agent_rounded,
    Brand.blue,
    'Real human therapy',
    'Talk with a licensed therapist in private one-on-one sessions, right '
        'from the app.',
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
          border: Border.all(color: Brand.border, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: feature.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(feature.icon, size: 22, color: feature.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feature.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Brand.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    feature.benefit,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Brand.textMuted,
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
    return OnboardingScaffold(
      step: 1,
      bottom: ElevatedButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CheckinScreen()),
        ),
        child: const Text('Continue'),
      ),
      children: [
        const Text(
          'Here to hold you up',
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
          'A quick look at what\'s inside — and how each piece helps you '
          'feel better, day by day.',
          style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.55),
        ),
        const SizedBox(height: 26),
        for (final (i, f) in _features.indexed) _card(i, f),
      ],
    );
  }
}
