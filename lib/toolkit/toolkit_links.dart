import 'package:flutter/material.dart';

import '../billing/pricing_copy.dart';
import '../home/home_ui.dart';
import '../meditation/breathing_screen.dart';
import '../meditation/meditation_catalog.dart';
import '../meditation/meditation_screen.dart';

/// Toolkits hand people on to the practices the app already has. These
/// look items up by title (a test keeps the titles honest) and apply the
/// same Premium gate the Meditations list does, so a toolkit card can't
/// slip past it.

Meditation meditationTitled(String title) => meditations.firstWhere(
  (m) => m.title == title,
  orElse: () => meditations.first,
);

BreathPattern breathPatternTitled(String title) => breathPatterns.firstWhere(
  (p) => p.title == title,
  orElse: () => breathPatterns.first,
);

/// True when [item] may open now; otherwise shows the upgrade sheet and
/// returns false. The gate every toolkit practice card goes through.
bool allowPractice(
  BuildContext context, {
  required bool premium,
  required String item,
  String source = 'toolkit',
}) => _allowed(context, premium, item, source);

bool _allowed(BuildContext context, bool premium, String item, String source) {
  if (premium && !isPremiumUser()) {
    showUpgradeSheet(
      context,
      item: item,
      source: source,
      title: 'This session is part of Premium',
      message:
          'Free includes a taste of each practice. Premium unlocks '
          'every session — and $introOffer.',
    );
    return false;
  }
  return true;
}

/// Opens a guided meditation by title, or the upgrade sheet if it's locked.
void openMeditation(
  BuildContext context,
  String title, {
  String source = 'toolkit',
}) {
  final m = meditationTitled(title);
  if (!_allowed(context, m.premium, m.title, source)) return;
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => MeditationScreen(meditation: m)));
}

/// Opens a breathing pattern by title, or the upgrade sheet if it's locked.
void openBreathing(
  BuildContext context,
  String title, {
  String source = 'toolkit',
}) {
  final p = breathPatternTitled(title);
  if (!_allowed(context, p.premium, p.title, source)) return;
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => BreathingScreen(pattern: p)));
}
