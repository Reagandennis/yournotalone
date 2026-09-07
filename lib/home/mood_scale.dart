import 'package:flutter/material.dart';

import '../brand.dart';

/// One step of the daily mood scale. The order of [moodLevels] is the
/// order shown in the check-in, and its index is the score minus one —
/// the same index [MoodRepository.moodKeys] uses for the database.
class MoodLevel {
  const MoodLevel(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Warm colours for the hard days, cool blues for the good ones — all
/// drawn from the pillar palette.
const moodLevels = [
  MoodLevel('Awful', Icons.sentiment_very_dissatisfied_rounded, Brand.red),
  MoodLevel('Low', Icons.sentiment_dissatisfied_rounded, Color(0xFFEF7418)),
  MoodLevel('Okay', Icons.sentiment_neutral_rounded, Brand.yellow),
  MoodLevel('Good', Icons.sentiment_satisfied_alt_rounded, Color(0xFF5E8BDD)),
  MoodLevel('Great', Icons.sentiment_very_satisfied_rounded, Brand.blue),
];

/// Colour of an unpicked face, and of a day with no check-in.
const moodIdle = Color(0xFFBEBEC6);
