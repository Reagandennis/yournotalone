import 'package:flutter/material.dart';

import '../meditation/breathing_screen.dart';
import '../meditation/meditation_screen.dart';
import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_content.dart';
import '../toolkit/toolkit_links.dart';
import 'awake_screen.dart';
import 'sleep_diary_screen.dart';
import 'sleep_habits_screen.dart';
import 'tomorrow_list_screen.dart';
import 'wind_down_screen.dart';

/// The practices from the main catalogue that belong to this programme.
/// A test checks these titles exist, so a rename fails the build.
const sleepMeditationTitle = 'Sleep wind-down';
const sleepBreathingTitle = '4-7-8 calm';

/// The tools, in the order that helps most: fix the evening first, then
/// the night, then measure.
final sleepTools = <ToolkitTool>[
  const ToolkitTool(
    title: 'Wind-down plan',
    blurb: 'An hour of small steps that tell your body it\'s night.',
    minutes: 4,
    icon: Icons.nights_stay_rounded,
    art: ToolkitArtKind.windDown,
    open: _windDown,
  ),
  const ToolkitTool(
    title: 'Put the day down',
    blurb: 'Tomorrow\'s three things and one you\'re letting go, on paper.',
    minutes: 3,
    icon: Icons.edit_note_rounded,
    art: ToolkitArtKind.tomorrowList,
    open: _tomorrow,
  ),
  const ToolkitTool(
    title: 'Awake at 3am?',
    blurb:
        'What to do when sleep won\'t come, so the bed stays a place for sleep.',
    minutes: 15,
    icon: Icons.bedtime_off_rounded,
    art: ToolkitArtKind.awake,
    open: _awake,
  ),
  const ToolkitTool(
    title: 'Sleep diary',
    blurb:
        'Log last night in a minute. Two weeks in, it tells you what to change.',
    minutes: 2,
    icon: Icons.auto_stories_rounded,
    art: ToolkitArtKind.diary,
    open: _diary,
  ),
  const ToolkitTool(
    title: 'Sleep habits check',
    blurb: 'Ten questions, and a fix for each one you say yes to.',
    minutes: 3,
    icon: Icons.checklist_rounded,
    art: ToolkitArtKind.habits,
    open: _habits,
  ),
  ToolkitTool(
    title: 'Sleep wind-down meditation',
    blurb: 'Put the day down gently and let your body get heavy.',
    minutes: meditationTitled(sleepMeditationTitle).minutes,
    meta:
        '${meditationTitled(sleepMeditationTitle).premium ? 'Premium · ' : ''}'
        '${meditationTitled(sleepMeditationTitle).minutes} min',
    icon: Icons.self_improvement_rounded,
    art: ToolkitArtKind.moon,
    open: (_) =>
        MeditationScreen(meditation: meditationTitled(sleepMeditationTitle)),
    guard: (context) => allowPractice(
      context,
      premium: meditationTitled(sleepMeditationTitle).premium,
      item: sleepMeditationTitle,
      source: 'toolkit:sleep',
    ),
  ),
  ToolkitTool(
    title: '4-7-8 breathing',
    blurb: 'A long hold and slow release that tells your body it\'s safe.',
    minutes: 3,
    meta:
        '${breathPatternTitled(sleepBreathingTitle).premium ? 'Premium · ' : ''}breathing',
    icon: Icons.air_rounded,
    art: ToolkitArtKind.sigh,
    open: (_) =>
        BreathingScreen(pattern: breathPatternTitled(sleepBreathingTitle)),
    guard: (context) => allowPractice(
      context,
      premium: breathPatternTitled(sleepBreathingTitle).premium,
      item: sleepBreathingTitle,
      source: 'toolkit:sleep',
    ),
  ),
];

Widget _windDown(BuildContext _) => const WindDownScreen();
Widget _tomorrow(BuildContext _) => const TomorrowListScreen();
Widget _awake(BuildContext _) => const AwakeScreen();
Widget _diary(BuildContext _) => const SleepDiaryScreen();
Widget _habits(BuildContext _) => const SleepHabitsScreen();
