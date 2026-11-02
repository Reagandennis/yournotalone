import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';

/// One step of the daily mood scale. The order of [moodLevels] is the
/// order shown in the check-in, and its index is the score minus one —
/// the same index [MoodRepository.moodKeys] uses for the database.
class MoodLevel {
  const MoodLevel(this.label, this.color);

  /// The English name, which also picks the face's shape in `MoodFace`.
  /// Show [name] instead.
  final String label;
  final Color color;

  /// The name shown on screen, in the app's language.
  String name(AppLocalizations l10n) => switch (label) {
    'Awful' => l10n.moodAwful,
    'Low' => l10n.moodLow,
    'Okay' => l10n.moodOkay,
    'Good' => l10n.moodGood,
    _ => l10n.moodGreat,
  };
}

/// Warm colours for the hard days, cool blues for the good ones — all
/// drawn from the pillar palette. Each is drawn as a character by
/// `MoodFace` (mood_face.dart). These are the light-mode colours: draw them
/// through `context.brand.art` (a face, a bar) or `.accent` (a label).
const moodLevels = [
  MoodLevel('Awful', Pillars.red),
  MoodLevel('Low', Color(0xFFEF7418)),
  MoodLevel('Okay', Pillars.yellow),
  MoodLevel('Good', Color(0xFF5E8BDD)),
  MoodLevel('Great', Pillars.blue),
];

/// Colour of a day with no check-in.
Color moodIdleColor(BrandColors c) =>
    c.isDark ? const Color(0xFF3A5278) : const Color(0xFFBEBEC6);
