import 'package:flutter/material.dart';

import '../meditation/breathing_screen.dart';
import '../meditation/meditation_screen.dart';
import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_content.dart';
import '../toolkit/toolkit_links.dart';
import 'control_circle_screen.dart';
import 'muscle_relaxation_screen.dart';
import 'recharge_screen.dart';
import 'sigh_screen.dart';
import 'stress_checkin_screen.dart';

/// The practices from the main catalogue that belong to this programme.
/// A test checks these titles exist, so a rename fails the build.
const stressMeditationTitle = 'Midday reset';
const stressBreathingTitle = 'Slow exhale';

/// The tools: measure, then downshift the body, then sort the load.
final stressTools = <ToolkitTool>[
  const ToolkitTool(
    title: 'Physiological sigh',
    blurb: 'Two breaths in, one long breath out. The fastest way to downshift.',
    minutes: 1,
    icon: Icons.air_rounded,
    art: ToolkitArtKind.sigh,
    open: _sigh,
    // The free taste of the programme.
    premium: false,
  ),
  const ToolkitTool(
    title: 'Tense and release',
    blurb:
        'Progressive muscle relaxation, group by group, with the timer kept.',
    minutes: 8,
    icon: Icons.accessibility_new_rounded,
    art: ToolkitArtKind.muscles,
    open: _muscles,
  ),
  const ToolkitTool(
    title: 'Stress check-in',
    blurb: 'Five questions about the past week, and a trend you can watch.',
    minutes: 2,
    icon: Icons.speed_rounded,
    art: ToolkitArtKind.gauge,
    open: _checkin,
  ),
  const ToolkitTool(
    title: 'What\'s in your hands',
    blurb: 'Sort what\'s weighing on you into control, influence and accept.',
    minutes: 6,
    icon: Icons.adjust_rounded,
    art: ToolkitArtKind.circles,
    open: _circle,
  ),
  const ToolkitTool(
    title: 'Recharge list',
    blurb: 'What drains you, what refills you, and one refill for today.',
    minutes: 4,
    icon: Icons.battery_charging_full_rounded,
    art: ToolkitArtKind.battery,
    open: _recharge,
  ),
  ToolkitTool(
    title: 'Midday reset',
    blurb: 'Put the morning down before you pick the afternoon up.',
    minutes: meditationTitled(stressMeditationTitle).minutes,
    meta:
        '${meditationTitled(stressMeditationTitle).premium ? 'Premium · ' : ''}'
        '${meditationTitled(stressMeditationTitle).minutes} min',
    icon: Icons.self_improvement_rounded,
    art: ToolkitArtKind.pause,
    premium: meditationTitled(stressMeditationTitle).premium,
    open: (_) =>
        MeditationScreen(meditation: meditationTitled(stressMeditationTitle)),
    guard: (context) => allowPractice(
      context,
      premium: meditationTitled(stressMeditationTitle).premium,
      item: stressMeditationTitle,
      source: 'toolkit:stress',
    ),
  ),
  ToolkitTool(
    title: 'Slow exhale breathing',
    blurb: 'Breathing out longer than in — the quickest way to downshift.',
    minutes: 3,
    meta:
        '${breathPatternTitled(stressBreathingTitle).premium ? 'Premium · ' : ''}breathing',
    icon: Icons.waves_rounded,
    art: ToolkitArtKind.worry,
    premium: breathPatternTitled(stressBreathingTitle).premium,
    open: (_) =>
        BreathingScreen(pattern: breathPatternTitled(stressBreathingTitle)),
    guard: (context) => allowPractice(
      context,
      premium: breathPatternTitled(stressBreathingTitle).premium,
      item: stressBreathingTitle,
      source: 'toolkit:stress',
    ),
  ),
];

Widget _sigh(BuildContext _) => const SighScreen();
Widget _muscles(BuildContext _) => const MuscleRelaxationScreen();
Widget _checkin(BuildContext _) => const StressCheckinScreen();
Widget _circle(BuildContext _) => const ControlCircleScreen();
Widget _recharge(BuildContext _) => const RechargeScreen();
