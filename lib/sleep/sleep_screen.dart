import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
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
    final l10n = context.l10n;
    return ToolkitHub(
      title: l10n.sleepHubTitle,
      accent: sleepAccent,
      headline: l10n.sleepHubHeadline,
      intro: l10n.sleepHubIntro,
      tools: sleepTools,
      lessons: sleepLessons,
      resources: sleepResources,
      resourceArt: ToolkitArtKind.resources,
      source: 'sleep',
      footer: ToolkitBanner(
        icon: Icons.graphic_eq_rounded,
        iconColor: c.yellow,
        tint: c.tint(Pillars.yellow, 0.08),
        title: l10n.sleepHubSoundsTitle,
        detail: l10n.sleepHubSoundsDetail,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SoundsScreen())),
      ),
      footnote: l10n.sleepHubFootnote,
    );
  }
}
