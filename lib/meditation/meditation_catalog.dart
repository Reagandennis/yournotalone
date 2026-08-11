import 'package:flutter/material.dart';

import '../brand.dart';

const chimeAsset = 'assets/sounds/chime.m4a';

/// A guided breathing rhythm: seconds for each phase of the cycle.
/// A phase of 0 seconds is skipped.
class BreathPattern {
  const BreathPattern(
    this.title,
    this.detail,
    this.accent, {
    required this.inhale,
    this.holdIn = 0,
    required this.exhale,
    this.holdOut = 0,
    this.premium = true,
  });

  final String title;
  final String detail;
  final Color accent;
  final int inhale;
  final int holdIn;
  final int exhale;
  final int holdOut;
  final bool premium;

  int get cycleSeconds => inhale + holdIn + exhale + holdOut;

  String get rhythmLabel => [inhale, holdIn, exhale, holdOut]
      .where((s) => s > 0)
      .join(' · ');
}

const breathPatterns = [
  BreathPattern(
    'Box breathing',
    'Even sides, steady mind — used by athletes and navy divers alike.',
    Brand.blue,
    inhale: 4,
    holdIn: 4,
    exhale: 4,
    holdOut: 4,
    premium: false,
  ),
  BreathPattern(
    '4-7-8 calm',
    'A long hold and slow release that tells your body it\'s safe.',
    Brand.yellow,
    inhale: 4,
    holdIn: 7,
    exhale: 8,
  ),
  BreathPattern(
    'Slow exhale',
    'Breathing out longer than in — the quickest way to downshift.',
    Brand.ink,
    inhale: 4,
    exhale: 7,
  ),
];

/// A timed meditation with gentle on-screen guidance. [prompts] are
/// (fraction-of-session, text) pairs shown as the session progresses.
class Meditation {
  const Meditation(
    this.title,
    this.detail,
    this.minutes,
    this.icon,
    this.accent, {
    this.premium = true,
    required this.prompts,
  });

  final String title;
  final String detail;
  final int minutes;
  final IconData icon;
  final Color accent;
  final bool premium;
  final List<(double, String)> prompts;
}

const meditations = [
  Meditation(
    'Morning grounding',
    'Arrive in your day before the day arrives at you.',
    5,
    Icons.wb_twilight_rounded,
    Brand.yellow,
    premium: false,
    prompts: [
      (0.0, 'Find a comfortable seat and let your eyes soften or close.'),
      (0.07, 'Take a slow breath in… and let it all the way out.'),
      (0.18, 'Feel the weight of your body — held and supported.'),
      (0.32, 'Notice your breath moving on its own. No need to change it.'),
      (0.48, 'When your mind wanders, that\'s okay. Gently come back.'),
      (0.63, 'Ask quietly: what would make today feel gentle?'),
      (0.8, 'Rest here a little longer. There\'s nowhere else to be.'),
      (0.94, 'Slowly bring small movements back. You\'re ready.'),
    ],
  ),
  Meditation(
    'Anxiety relief',
    'Ground yourself in what\'s real and right here.',
    8,
    Icons.spa_rounded,
    Brand.blue,
    prompts: [
      (0.0, 'Settle in. Let your shoulders drop away from your ears.'),
      (0.06, 'Breathe out longer than you breathe in, just for a while.'),
      (0.16, 'Name five things you can feel touching your body.'),
      (0.3, 'Anxiety is a wave — it rises, peaks, and always passes.'),
      (0.45, 'Place a hand on your chest. Feel it rise and fall.'),
      (0.6, 'You don\'t have to solve anything right now.'),
      (0.75, 'With each exhale, let your jaw and hands soften.'),
      (0.9, 'You\'re safe in this moment. Stay as long as you like.'),
    ],
  ),
  Meditation(
    'Body scan',
    'Travel slowly from head to toe, releasing as you go.',
    12,
    Icons.accessibility_new_rounded,
    Brand.red,
    prompts: [
      (0.0, 'Lie down or sit back. Close your eyes when you\'re ready.'),
      (0.05, 'Bring your attention to the top of your head.'),
      (0.14, 'Soften your forehead, your eyes, your jaw.'),
      (0.25, 'Notice your neck and shoulders. Breathe into any tightness.'),
      (0.37, 'Follow your arms down to your fingertips.'),
      (0.5, 'Feel your chest and belly rise and fall.'),
      (0.62, 'Let your back release into whatever holds you.'),
      (0.74, 'Move through your hips, your legs, your knees.'),
      (0.86, 'Reach your feet. Feel them, heavy and warm.'),
      (0.95, 'Hold your whole body in awareness. Rest.'),
    ],
  ),
  Meditation(
    'Sleep wind-down',
    'Put the day down gently and let your body get heavy.',
    10,
    Icons.bedtime_rounded,
    Brand.ink,
    prompts: [
      (0.0, 'Get comfortable — this one can end in sleep.'),
      (0.08, 'Let today be finished. Nothing more is needed from you.'),
      (0.2, 'Breathe slower on each exhale, sinking a little deeper.'),
      (0.35, 'Let your body feel heavy, like sand settling.'),
      (0.52, 'Thoughts may drift by. Let them pass like clouds.'),
      (0.7, 'Warmth in your hands. Warmth in your feet.'),
      (0.85, 'There\'s nothing to do now but rest.'),
    ],
  ),
  Meditation(
    'Loving kindness',
    'Turn some warmth toward yourself and the people you carry.',
    6,
    Icons.favorite_rounded,
    Brand.red,
    prompts: [
      (0.0, 'Sit comfortably and bring a soft breath in.'),
      (0.08, 'Picture yourself as you are right now.'),
      (0.2, 'Quietly offer: may I be safe. May I be well.'),
      (0.35, 'May I be kind to myself, especially on hard days.'),
      (0.5, 'Now picture someone you care about.'),
      (0.62, 'Offer them the same: may you be safe. May you be well.'),
      (0.78, 'Let that warmth widen — to strangers, to everyone.'),
      (0.93, 'Come back to yourself. Carry this with you.'),
    ],
  ),
];
