import 'package:flutter/material.dart';

import '../brand.dart';
import '../sounds/sounds_screen.dart';
import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_hub.dart';
import 'sleep_catalog.dart';
import 'sleep_content.dart';

/// Sleep better: the parts of CBT for insomnia that work on their own —
/// a wind-down, the 20-minute rule, a diary, a habits check — plus the
/// app's sleep practices and the best free courses elsewhere.
class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SleepScreen());

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return ToolkitHub(
      title: 'Sleep better',
      accent: sleepAccent,
      headline: 'Sleep is built in the daytime',
      intro:
          'Most sleep problems aren\'t fixed in bed. They\'re fixed by a '
          'steady wake time, an evening that winds down on purpose, and '
          'not fighting the nights that go wrong. These are the tools sleep '
          'clinics use — cognitive behavioural therapy for insomnia — in a '
          'form you can start tonight.',
      tools: sleepTools,
      lessons: sleepLessons,
      resources: sleepResources,
      resourceArt: ToolkitArtKind.resources,
      source: 'sleep',
      footer: ToolkitBanner(
        icon: Icons.graphic_eq_rounded,
        iconColor: c.yellow,
        tint: c.tint(Pillars.yellow, 0.08),
        title: 'Sounds to fall asleep to',
        detail:
            'Rainfall, crickets, pink noise and more — loops that keep '
            'going after you\'ve stopped listening.',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SoundsScreen())),
      ),
      footnote:
          'Snoring with pauses in breathing, falling asleep in the '
          'day, or insomnia that\'s lasted months deserve a doctor\'s look. '
          'These tools sit alongside that, not instead of it.',
    );
  }
}
