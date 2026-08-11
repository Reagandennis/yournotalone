import 'package:flutter/material.dart';

import '../brand.dart';

enum SoundCategory {
  focus('Focus', Brand.yellow),
  sleep('Sleep', Brand.ink),
  calm('Calm', Brand.blue);

  const SoundCategory(this.label, this.accent);

  final String label;
  final Color accent;
}

/// One ambient sound, including the character of its animated wave:
/// [waveFreq] is how many ripples span the screen, [waveSpeed] how fast
/// they travel, and [pulse] adds a cricket-like throb.
class Sound {
  const Sound(
    this.title,
    this.detail,
    this.icon,
    this.category,
    this.asset, {
    this.premium = true,
    this.waveFreq = 3,
    this.waveSpeed = 1,
    this.waveHeight = 0.5,
    this.pulse = false,
  });

  final String title;
  final String detail;
  final IconData icon;
  final SoundCategory category;
  final String asset;
  final bool premium;
  final double waveFreq;
  final int waveSpeed;
  final double waveHeight;
  final bool pulse;
}

const soundsCatalog = [
  Sound(
    'Deep focus',
    'Low, steady noise that softens distraction.',
    Icons.graphic_eq_rounded,
    SoundCategory.focus,
    'assets/sounds/deep_focus.m4a',
    premium: false,
    waveFreq: 2.5,
    waveSpeed: 1,
    waveHeight: 0.55,
  ),
  Sound(
    'White noise',
    'The classic — masks the world evenly.',
    Icons.blur_on_rounded,
    SoundCategory.focus,
    'assets/sounds/white_noise.m4a',
    waveFreq: 9,
    waveSpeed: 4,
    waveHeight: 0.3,
  ),
  Sound(
    'Rainfall',
    'Steady rain on a quiet evening.',
    Icons.water_drop_outlined,
    SoundCategory.sleep,
    'assets/sounds/rainfall.m4a',
    waveFreq: 7,
    waveSpeed: 3,
    waveHeight: 0.4,
  ),
  Sound(
    'Crickets at night',
    'A calm field long after sunset.',
    Icons.nightlight_outlined,
    SoundCategory.sleep,
    'assets/sounds/crickets_night.m4a',
    waveFreq: 5,
    waveSpeed: 2,
    waveHeight: 0.45,
    pulse: true,
  ),
  Sound(
    'Ocean waves',
    'Slow swells rolling in and out.',
    Icons.waves_rounded,
    SoundCategory.calm,
    'assets/sounds/ocean_waves.m4a',
    waveFreq: 1.6,
    waveSpeed: 1,
    waveHeight: 0.75,
  ),
];
