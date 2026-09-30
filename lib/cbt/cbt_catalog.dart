import 'package:flutter/material.dart';

import 'activity_planner_screen.dart';
import 'cbt_art.dart';
import 'grounding_screen.dart';
import 'problem_solving_screen.dart';
import 'thinking_traps_screen.dart';
import 'thought_record_screen.dart';
import 'worry_time_screen.dart';

/// One tool in the CBT toolkit, and the screen that runs it.
class CbtTool {
  const CbtTool({
    required this.title,
    required this.blurb,
    required this.minutes,
    required this.icon,
    required this.art,
    required this.open,
  });

  final String title;
  final String blurb;

  /// Roughly how long it takes; shown on the card and in search.
  final int minutes;
  final IconData icon;
  final CbtArtKind art;
  final WidgetBuilder open;
}

/// The tools, in the order a therapist would usually introduce them:
/// steady first, then notice, then check, then act.
const cbtTools = <CbtTool>[
  CbtTool(
    title: 'Grounding: 5-4-3-2-1',
    blurb: 'Back into the room when panic or a spiral takes over.',
    minutes: 3,
    icon: Icons.spa_rounded,
    art: CbtArtKind.grounding,
    open: _grounding,
  ),
  CbtTool(
    title: 'Thought record',
    blurb: 'Catch the thought, check the evidence, write a fairer one.',
    minutes: 8,
    icon: Icons.edit_note_rounded,
    art: CbtArtKind.thoughts,
    open: _thoughtRecord,
  ),
  CbtTool(
    title: 'Thinking traps',
    blurb: 'Eleven patterns anxious and low moods run on, and how to spot them.',
    minutes: 5,
    icon: Icons.psychology_rounded,
    art: CbtArtKind.traps,
    open: _traps,
  ),
  CbtTool(
    title: 'One small thing',
    blurb: 'Plan up to three doable things for today. Mood follows action.',
    minutes: 4,
    icon: Icons.wb_sunny_rounded,
    art: CbtArtKind.activity,
    open: _activity,
  ),
  CbtTool(
    title: 'Worry window',
    blurb: 'Park worries as they come; give them fifteen minutes, once a day.',
    minutes: 15,
    icon: Icons.schedule_rounded,
    art: CbtArtKind.worry,
    open: _worry,
  ),
  CbtTool(
    title: 'Problem solving',
    blurb: 'Name it, list the options, pick one, take a first step.',
    minutes: 10,
    icon: Icons.lightbulb_rounded,
    art: CbtArtKind.problem,
    open: _problem,
  ),
];

Widget _grounding(BuildContext _) => const GroundingScreen();
Widget _thoughtRecord(BuildContext _) => const ThoughtRecordScreen();
Widget _traps(BuildContext _) => const ThinkingTrapsScreen();
Widget _activity(BuildContext _) => const ActivityPlannerScreen();
Widget _worry(BuildContext _) => const WorryTimeScreen();
Widget _problem(BuildContext _) => const ProblemSolvingScreen();
