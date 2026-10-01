import 'package:flutter/material.dart';

import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_content.dart';
import 'activity_planner_screen.dart';
import 'grounding_screen.dart';
import 'problem_solving_screen.dart';
import 'thinking_traps_screen.dart';
import 'thought_record_screen.dart';
import 'worry_time_screen.dart';

/// The tools, in the order a therapist would usually introduce them:
/// steady first, then notice, then check, then act.
const cbtTools = <ToolkitTool>[
  ToolkitTool(
    title: 'Grounding: 5-4-3-2-1',
    blurb: 'Back into the room when panic or a spiral takes over.',
    minutes: 3,
    icon: Icons.spa_rounded,
    art: ToolkitArtKind.grounding,
    open: _grounding,
    // The free taste of the toolkit.
    premium: false,
  ),
  ToolkitTool(
    title: 'Thought record',
    blurb: 'Catch the thought, check the evidence, write a fairer one.',
    minutes: 8,
    icon: Icons.edit_note_rounded,
    art: ToolkitArtKind.thoughts,
    open: _thoughtRecord,
  ),
  ToolkitTool(
    title: 'Thinking traps',
    blurb:
        'Eleven patterns anxious and low moods run on, and how to spot them.',
    minutes: 5,
    icon: Icons.psychology_rounded,
    art: ToolkitArtKind.traps,
    open: _traps,
  ),
  ToolkitTool(
    title: 'One small thing',
    blurb: 'Plan up to three doable things for today. Mood follows action.',
    minutes: 4,
    icon: Icons.wb_sunny_rounded,
    art: ToolkitArtKind.activity,
    open: _activity,
  ),
  ToolkitTool(
    title: 'Worry window',
    blurb: 'Park worries as they come; give them fifteen minutes, once a day.',
    minutes: 15,
    icon: Icons.schedule_rounded,
    art: ToolkitArtKind.worry,
    open: _worry,
  ),
  ToolkitTool(
    title: 'Problem solving',
    blurb: 'Name it, list the options, pick one, take a first step.',
    minutes: 10,
    icon: Icons.lightbulb_rounded,
    art: ToolkitArtKind.problem,
    open: _problem,
  ),
];

Widget _grounding(BuildContext _) => const GroundingScreen();
Widget _thoughtRecord(BuildContext _) => const ThoughtRecordScreen();
Widget _traps(BuildContext _) => const ThinkingTrapsScreen();
Widget _activity(BuildContext _) => const ActivityPlannerScreen();
Widget _worry(BuildContext _) => const WorryTimeScreen();
Widget _problem(BuildContext _) => const ProblemSolvingScreen();
