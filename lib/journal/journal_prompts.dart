import 'package:flutter/material.dart';

import '../brand.dart';

/// A guided writing prompt. [seed] is dropped into a fresh entry so the
/// page is never blank — the user just keeps the sentence going.
class JournalPrompt {
  const JournalPrompt(
    this.title,
    this.detail,
    this.icon,
    this.accent, {
    required this.group,
    required this.seed,
    this.premium = true,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color accent;

  /// Heading this prompt sits under in the journal hub.
  final String group;
  final String seed;
  final bool premium;
}

/// Group headings, in the order the hub shows them.
const promptGroups = [
  'Everyday',
  'Hard days',
  'Looking back',
  'Recovery',
  'Before sleep',
];

const journalPrompts = [
  // ── Everyday ───────────────────────────────────────────────────
  JournalPrompt(
    'Gratitude',
    'Three small things that went right.',
    Icons.wb_sunny_rounded,
    Pillars.yellow,
    group: 'Everyday',
    seed: 'Today, I\'m grateful for ',
    premium: false,
  ),
  JournalPrompt(
    'Let it out',
    'No filter, no editing — just get it down.',
    Icons.bolt_rounded,
    Pillars.red,
    group: 'Everyday',
    seed: 'What\'s sitting heaviest on me right now is ',
  ),
  JournalPrompt(
    'What I need',
    'Name it plainly, then see who could help.',
    Icons.favorite_rounded,
    Pillars.red,
    group: 'Everyday',
    seed: 'Right now, what I need most is ',
  ),
  JournalPrompt(
    'Three lines',
    'One thing that happened, one feeling, one thought.',
    Icons.short_text_rounded,
    Pillars.blue,
    group: 'Everyday',
    seed: 'What happened:\n\nHow it felt:\n\nWhat I make of it:\n',
  ),
  JournalPrompt(
    'Body check-in',
    'Where the day is sitting — shoulders, chest, jaw.',
    Icons.accessibility_new_rounded,
    Pillars.black,
    group: 'Everyday',
    seed: 'My body today feels ',
  ),

  // ── Hard days ──────────────────────────────────────────────────
  JournalPrompt(
    'Worry dump',
    'Everything circling, out of your head and onto the page.',
    Icons.cyclone_rounded,
    Pillars.black,
    group: 'Hard days',
    seed: 'Everything I\'m worried about right now:\n\n- ',
  ),
  JournalPrompt(
    'Advice to a friend',
    'The kindness you\'d hand someone else, turned around.',
    Icons.volunteer_activism_rounded,
    Pillars.red,
    group: 'Hard days',
    seed: 'If a friend told me they were going through this, I\'d say ',
  ),
  JournalPrompt(
    'After a panic',
    'Write it down while it\'s fresh, so it teaches you something.',
    Icons.healing_rounded,
    Pillars.blue,
    group: 'Hard days',
    seed: 'What set it off:\n\nWhat it felt like:\n\nWhat helped:\n\n'
        'What I want to remember for next time:\n',
  ),
  JournalPrompt(
    'Anger on paper',
    'Say the unsaid version here, where it costs nothing.',
    Icons.local_fire_department_rounded,
    Pillars.red,
    group: 'Hard days',
    seed: 'What I\'m actually angry about is ',
  ),
  JournalPrompt(
    'Worst case',
    'Follow the fear all the way down, then look at it.',
    Icons.psychology_rounded,
    Pillars.black,
    group: 'Hard days',
    seed: 'The thing I\'m afraid of is \n\nIf that happened, I would ',
  ),

  // ── Looking back ───────────────────────────────────────────────
  JournalPrompt(
    'Wins of the week',
    'Count what you carried, not what you missed.',
    Icons.emoji_events_rounded,
    Pillars.blue,
    group: 'Looking back',
    seed: 'This week I\'m proud that I ',
  ),
  JournalPrompt(
    'Who showed up',
    'The people who made this week lighter, named.',
    Icons.people_alt_rounded,
    Pillars.yellow,
    group: 'Looking back',
    seed: 'Someone who made this week easier was ',
  ),
  JournalPrompt(
    'Letter to myself',
    'Write to the you who reads this next month.',
    Icons.mail_outline_rounded,
    Pillars.black,
    group: 'Looking back',
    seed: 'Dear me,\n\nBy the time you read this, ',
  ),
  JournalPrompt(
    'A month from now',
    'What you want to be true, in your own words.',
    Icons.flag_rounded,
    Pillars.blue,
    group: 'Looking back',
    seed: 'A month from now, I want to be able to say that I ',
  ),

  // ── Recovery ───────────────────────────────────────────────────
  JournalPrompt(
    'Why I started',
    'The reason, in your handwriting, for the days you forget it.',
    Icons.anchor_rounded,
    Pillars.black,
    group: 'Recovery',
    seed: 'I started this because ',
  ),
  JournalPrompt(
    'After the urge',
    'What it wanted, what it cost, what it passed like.',
    Icons.surfing_rounded,
    Pillars.red,
    group: 'Recovery',
    seed: 'When the urge came:\n\nWhat I was really needing:\n\n'
        'What I did instead:\n',
  ),
  JournalPrompt(
    'One day at a time',
    'Just today. Nothing about tomorrow.',
    Icons.today_rounded,
    Pillars.yellow,
    group: 'Recovery',
    seed: 'Today, the thing I\'m choosing is ',
  ),

  // ── Before sleep ───────────────────────────────────────────────
  JournalPrompt(
    'Put the day down',
    'Close the loops so they stop reopening at 2am.',
    Icons.bedtime_rounded,
    Pillars.black,
    group: 'Before sleep',
    seed: 'Finished today:\n\n- \n\nWaiting for tomorrow:\n\n- \n',
  ),
  JournalPrompt(
    'Tomorrow, gently',
    'One thing you\'ll do, and one thing you won\'t.',
    Icons.wb_twilight_rounded,
    Pillars.yellow,
    group: 'Before sleep',
    seed: 'Tomorrow I\'ll make room for \n\nAnd I\'m letting go of ',
  ),
];
