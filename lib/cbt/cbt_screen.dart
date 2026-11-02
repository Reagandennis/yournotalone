import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../therapy/therapy_screen.dart';
import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_hub.dart';
import 'cbt_catalog.dart';
import 'cbt_content.dart';

/// The CBT toolkit: the exercises therapists teach most, short reads on
/// the ideas behind them, and the best free material elsewhere. Every tool
/// works on its own, and nothing is saved unless the person chooses to.
class CbtScreen extends StatelessWidget {
  const CbtScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const CbtScreen());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ToolkitHub(
      title: l10n.cbtTitle,
      accent: cbtAccent,
      headline: l10n.cbtHeadline,
      intro: l10n.cbtIntro,
      tools: cbtTools,
      lessons: cbtLessons,
      resources: cbtResources,
      resourceArt: ToolkitArtKind.resources,
      source: 'cbt',
      footer: ToolkitBanner(
        icon: Icons.favorite_rounded,
        iconColor: context.brand.red,
        title: l10n.cbtTherapistBannerTitle,
        detail: l10n.cbtTherapistBannerDetail,
        onTap: () => Navigator.of(context).push(TherapyScreen.route()),
      ),
      footnote: l10n.cbtFootnote,
    );
  }
}
