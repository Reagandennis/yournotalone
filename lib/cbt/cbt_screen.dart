import 'package:flutter/material.dart';

import '../brand.dart';
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
    return ToolkitHub(
      title: 'CBT toolkit',
      accent: cbtAccent,
      headline: 'Skills you can use today',
      intro:
          'Cognitive behavioural therapy is the best-studied talking '
          'therapy for anxiety and depression, and much of it is learnable. '
          'These are the tools therapists hand out first — for the minutes '
          'between sessions, or before you\'ve had one.',
      tools: cbtTools,
      lessons: cbtLessons,
      resources: cbtResources,
      resourceArt: ToolkitArtKind.resources,
      source: 'cbt',
      footer: ToolkitBanner(
        icon: Icons.favorite_rounded,
        iconColor: context.brand.red,
        title: 'Want to do this with someone?',
        detail:
            'A licensed therapist can take you through these properly. '
            'Book a private video session.',
        onTap: () => Navigator.of(context).push(TherapyScreen.route()),
      ),
      footnote:
          'Self-help is not a substitute for care in a crisis. If '
          'you\'re in immediate danger, use Get help now on the Home screen.',
    );
  }
}
