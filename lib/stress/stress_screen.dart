import 'package:flutter/material.dart';

import '../brand.dart';
import '../cbt/cbt_screen.dart';
import '../therapy/therapy_screen.dart';
import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_hub.dart';
import 'stress_catalog.dart';
import 'stress_content.dart';

/// Manage stress: quick ways to bring the body down, a check-in to watch
/// the trend, and tools for sorting the load itself — plus where to turn
/// when it's more than stress.
class StressScreen extends StatelessWidget {
  const StressScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const StressScreen());

  @override
  Widget build(BuildContext context) {
    return ToolkitHub(
      title: 'Manage stress',
      accent: stressAccent,
      headline: 'Down from the ceiling, then sort the load',
      intro:
          'Stress is a body state before it\'s a thought, so the fastest '
          'tools work on the body: breath and muscles first, thinking '
          'second. Then a check-in to see the trend, and two tools for '
          'the load itself — what you can change, and what refills you.',
      tools: stressTools,
      lessons: stressLessons,
      resources: stressResources,
      resourceArt: ToolkitArtKind.resources,
      source: 'stress',
      footer: Column(
        children: [
          ToolkitBanner(
            icon: Icons.psychology_rounded,
            iconColor: Brand.red,
            tint: const Color(0x14C53C26),
            title: 'When the stress is in the thinking',
            detail:
                'Thought records, thinking traps and worry windows are '
                'in the CBT toolkit.',
            onTap: () => Navigator.of(context).push(CbtScreen.route()),
          ),
          const SizedBox(height: 12),
          ToolkitBanner(
            icon: Icons.favorite_rounded,
            iconColor: Brand.red,
            title: 'Been like this for months?',
            detail:
                'That\'s worth a real conversation. Book a private '
                'session with a licensed therapist.',
            onTap: () => Navigator.of(context).push(TherapyScreen.route()),
          ),
        ],
      ),
      footnote:
          'Chest pain, breathlessness or palpitations that don\'t '
          'settle need a doctor, not a breathing exercise. In an emergency, '
          'call your local emergency number.',
    );
  }
}
