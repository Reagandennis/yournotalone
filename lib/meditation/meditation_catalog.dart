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
    Pillars.blue,
    inhale: 4,
    holdIn: 4,
    exhale: 4,
    holdOut: 4,
    premium: false,
  ),
  BreathPattern(
    '4-7-8 calm',
    'A long hold and slow release that tells your body it\'s safe.',
    Pillars.yellow,
    inhale: 4,
    holdIn: 7,
    exhale: 8,
  ),
  BreathPattern(
    'Slow exhale',
    'Breathing out longer than in — the quickest way to downshift.',
    Pillars.black,
    inhale: 4,
    exhale: 7,
  ),
  BreathPattern(
    'Coherent breath',
    'Five in, five out — the steady pace your heart settles into.',
    Pillars.blue,
    inhale: 5,
    exhale: 5,
  ),
  BreathPattern(
    'Ocean breath',
    'Long and soft, like a wave drawing back from the shore.',
    Pillars.blue,
    inhale: 5,
    exhale: 7,
  ),
  BreathPattern(
    'Triangle breath',
    'In, hold, then a longer way out — for when your head is loud.',
    Pillars.yellow,
    inhale: 4,
    holdIn: 4,
    exhale: 6,
  ),
  BreathPattern(
    'Panic reset',
    'For the minutes when your chest races and you need out fast.',
    Pillars.red,
    inhale: 4,
    exhale: 6,
    holdOut: 2,
  ),
  BreathPattern(
    'Morning lift',
    'A fuller inhale to wake the body up without rushing it.',
    Pillars.yellow,
    inhale: 6,
    holdIn: 2,
    exhale: 4,
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
    Pillars.yellow,
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
    Pillars.blue,
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
    Pillars.red,
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
    Pillars.black,
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
    Pillars.red,
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
  Meditation(
    'Midday reset',
    'Put the morning down before you pick the afternoon up.',
    5,
    Icons.restart_alt_rounded,
    Pillars.yellow,
    prompts: [
      (0.0, 'Stop where you are. Both feet flat, hands still.'),
      (0.08, 'One long breath out — longer than feels necessary.'),
      (0.2, 'Whatever the morning was, it\'s already behind you.'),
      (0.36, 'Unclench your jaw. Drop your shoulders. Soften your eyes.'),
      (0.52, 'Notice one thing you can hear right now, near or far.'),
      (0.68, 'Nothing needs deciding in the next sixty seconds.'),
      (0.84, 'Ask: what is the one thing the afternoon actually needs?'),
      (0.94, 'Take that answer with you. Leave the rest here.'),
    ],
  ),
  Meditation(
    'Deep work focus',
    'Clear the desk in your head before you start.',
    7,
    Icons.center_focus_strong_rounded,
    Pillars.blue,
    prompts: [
      (0.0, 'Sit upright but easy. Phone face down.'),
      (0.07, 'Three slow breaths — in through the nose, out through the mouth.'),
      (0.18, 'Picture everything you\'re carrying, set down in a pile beside you.'),
      (0.32, 'It stays there. You can pick it up when this is done.'),
      (0.46, 'Rest your attention on the breath at the tip of your nose.'),
      (0.6, 'When it wanders — and it will — bring it back without comment.'),
      (0.74, 'Now name the single task you\'re about to do.'),
      (0.88, 'Hold it lightly. See yourself starting it, calm and unhurried.'),
      (0.96, 'Open your eyes. Begin with that one thing.'),
    ],
  ),
  Meditation(
    'Self-compassion',
    'Speak to yourself the way you\'d speak to a friend.',
    7,
    Icons.volunteer_activism_rounded,
    Pillars.red,
    prompts: [
      (0.0, 'Settle in. Place a hand somewhere that feels kind — chest, arm.'),
      (0.09, 'Bring to mind what\'s hurting. Just name it, gently.'),
      (0.22, 'Say inwardly: this is a hard moment.'),
      (0.36, 'Hard moments are part of every life. You\'re not alone in this.'),
      (0.5, 'Ask: what would I say to a friend sitting where I am?'),
      (0.64, 'Now say it to yourself, in your own words.'),
      (0.78, 'May I be kind to myself. May I give myself what I need.'),
      (0.9, 'Let your hand rest a moment longer before you go.'),
    ],
  ),
  Meditation(
    'Letting go of anger',
    'Feel it fully, then set down what it costs you to carry.',
    9,
    Icons.local_fire_department_rounded,
    Pillars.red,
    prompts: [
      (0.0, 'Sit somewhere you won\'t be interrupted. Let the eyes close.'),
      (0.07, 'Anger is allowed here. Nothing has to be forgiven yet.'),
      (0.17, 'Where do you feel it — jaw, chest, hands, stomach?'),
      (0.3, 'Breathe into that place. Don\'t push it away.'),
      (0.44, 'Underneath the anger, what else is there? Hurt? Fear? Shame?'),
      (0.58, 'Let that quieter feeling be seen for a moment.'),
      (0.72, 'Each exhale, let the grip loosen by a fraction.'),
      (0.86, 'You can put this down without saying it was okay.'),
      (0.95, 'Come back slowly. Notice what\'s lighter, even slightly.'),
    ],
  ),
  Meditation(
    'Walking meditation',
    'Ten minutes outside, with your attention in your feet.',
    10,
    Icons.directions_walk_rounded,
    Pillars.black,
    prompts: [
      (0.0, 'Start walking, slower than usual. No destination.'),
      (0.08, 'Feel the ground meet each foot — heel, then toe.'),
      (0.2, 'Let your arms swing. Unlock your knees.'),
      (0.33, 'Match your breath to your steps, whatever rhythm fits.'),
      (0.47, 'Take in what\'s around you without naming it.'),
      (0.6, 'If your thoughts run ahead, come back to your feet.'),
      (0.73, 'Notice the air on your face and hands.'),
      (0.86, 'Let the pace stay slow, even now.'),
      (0.95, 'Before you stop, take three full breaths standing still.'),
    ],
  ),
  Meditation(
    'Gratitude',
    'Count what\'s already here before reaching for more.',
    6,
    Icons.wb_sunny_rounded,
    Pillars.yellow,
    prompts: [
      (0.0, 'Sit comfortably. Let the breath find its own pace.'),
      (0.1, 'Bring to mind one small thing that went right today.'),
      (0.24, 'Stay with it. Let yourself actually feel it, not just note it.'),
      (0.4, 'Now someone who made this week easier, in any way.'),
      (0.55, 'Picture their face. Offer them a quiet thank you.'),
      (0.7, 'Now something about your own body that carried you today.'),
      (0.85, 'Nothing here is owed to you. Let that land softly.'),
      (0.95, 'Carry one of these with you into the rest of the day.'),
    ],
  ),
  Meditation(
    'Deep rest',
    'A long, guided lie-down for when sleep won\'t come.',
    15,
    Icons.nights_stay_rounded,
    Pillars.black,
    prompts: [
      (0.0, 'Lie on your back, arms a little away from your sides.'),
      (0.05, 'You don\'t need to fall asleep. Resting is enough.'),
      (0.13, 'Let the floor or the bed take your full weight.'),
      (0.24, 'Bring your attention to your right hand. Let it go heavy.'),
      (0.34, 'Now the left. Then both arms, from shoulder to fingertip.'),
      (0.45, 'Your legs, one at a time, sinking down.'),
      (0.56, 'Your back, your ribs, your belly — all released.'),
      (0.67, 'Your face: forehead, eyes, jaw, tongue, all soft.'),
      (0.78, 'Breath moving on its own, slow and unhurried.'),
      (0.88, 'Nothing to do, nowhere to be, no one needing you.'),
      (0.96, 'Stay as long as you like. Sleep if it comes.'),
    ],
  ),
];
