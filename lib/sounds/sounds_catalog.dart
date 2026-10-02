import 'package:flutter/material.dart';

import '../brand.dart';

enum SoundCategory {
  focus('Focus', Pillars.yellow),
  sleep('Sleep', Pillars.black),
  calm('Calm', Pillars.blue);

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
  // Focus
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
    'Brown noise',
    'Deeper than white — a low rumble that buries a noisy room.',
    Icons.surround_sound_rounded,
    SoundCategory.focus,
    'assets/sounds/brown_noise.m4a',
    waveFreq: 2,
    waveSpeed: 1,
    waveHeight: 0.6,
  ),
  Sound(
    'Stream',
    'Water over rocks — busy enough to work through.',
    Icons.water_rounded,
    SoundCategory.focus,
    'assets/sounds/mountain_stream.m4a',
    waveFreq: 6,
    waveSpeed: 3,
    waveHeight: 0.45,
  ),
  // Sleep
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
    'Pink noise',
    'Softer and warmer than white noise — easy to sleep through.',
    Icons.grain_rounded,
    SoundCategory.sleep,
    'assets/sounds/pink_noise.m4a',
    waveFreq: 7,
    waveSpeed: 3,
    waveHeight: 0.35,
  ),
  Sound(
    'Distant storm',
    'Rain that keeps going, with thunder rolling far off.',
    Icons.thunderstorm_rounded,
    SoundCategory.sleep,
    'assets/sounds/distant_storm.m4a',
    waveFreq: 3.5,
    waveSpeed: 2,
    waveHeight: 0.6,
    pulse: true,
  ),
  Sound(
    'Fireside',
    'A low roar and the crackle of a fire nearby.',
    Icons.local_fire_department_rounded,
    SoundCategory.sleep,
    'assets/sounds/fireside.m4a',
    waveFreq: 4,
    waveSpeed: 2,
    waveHeight: 0.5,
    pulse: true,
  ),
  // Calm
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
  Sound(
    'Singing bowl',
    'A struck bowl and its long, slow fade.',
    Icons.track_changes_rounded,
    SoundCategory.calm,
    'assets/sounds/singing_bowl.m4a',
    waveFreq: 1.4,
    waveSpeed: 1,
    waveHeight: 0.7,
  ),
  Sound(
    'Heartbeat',
    'Sixty beats a minute — the pace a settled body finds.',
    Icons.monitor_heart_rounded,
    SoundCategory.calm,
    'assets/sounds/resting_heartbeat.m4a',
    waveFreq: 1.6,
    waveSpeed: 1,
    waveHeight: 0.5,
    pulse: true,
  ),
  Sound(
    'Breathe',
    'Six breaths a minute — follow the swell and yours slows to meet it.',
    Icons.air_rounded,
    SoundCategory.calm,
    'assets/sounds/breathe_with_me.m4a',
    waveFreq: 1,
    waveSpeed: 1,
    waveHeight: 0.8,
  ),
];
