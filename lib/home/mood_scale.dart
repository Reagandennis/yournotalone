import 'package:flutter/material.dart';

import '../brand.dart';

/// One step of the daily mood scale. The order of [moodLevels] is the
/// order shown in the check-in, and its index is the score minus one —
/// the same index [MoodRepository.moodKeys] uses for the database.
class MoodLevel {
  const MoodLevel(this.label, this.color);

  final String label;
  final Color color;
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
