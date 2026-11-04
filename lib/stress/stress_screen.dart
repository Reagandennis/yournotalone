import 'package:flutter/material.dart';

import '../brand.dart';
import '../content/content_catalog.dart';
import '../l10n/l10n.dart';
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
    final c = context.brand;
    final l10n = context.l10n;
    return ToolkitHub(
      title: l10n.stressTitle,
      accent: stressAccent,
      headline: l10n.stressHeadline,
      intro: l10n.stressIntro,
      tools: toolkitTools(stressAccent, stressTools, ToolkitArtKind.pause),
      lessons: toolkitLessons(stressAccent, stressLessons),
      resources: stressResources,
      resourceArt: ToolkitArtKind.resources,
      source: 'stress',
      footer: Column(
        children: [
          ToolkitBanner(
            icon: Icons.psychology_rounded,
            iconColor: c.red,
            tint: c.tint(const Color(0xFFC53C26), 0.08),
            title: l10n.stressCbtBannerTitle,
            detail: l10n.stressCbtBannerDetail,
            onTap: () => Navigator.of(context).push(CbtScreen.route()),
          ),
          const SizedBox(height: 12),
          ToolkitBanner(
            icon: Icons.favorite_rounded,
            iconColor: c.red,
            title: l10n.stressTherapistBannerTitle,
            detail: l10n.stressTherapistBannerDetail,
            onTap: () => Navigator.of(context).push(TherapyScreen.route()),
          ),
        ],
      ),
      footnote: l10n.stressFootnote,
    );
  }
}
