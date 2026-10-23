import 'package:flutter/material.dart';

import '../cbt/cbt_content.dart';
import '../discover/content_index.dart';
import '../sleep/sleep_content.dart';
import '../stress/stress_content.dart';

/// One day of a course: an item from the index, and why it's today's.
class CourseDay {
  const CourseDay(this.itemId, this.note);

  /// A [ContentItem.id]; a test checks every one exists.
  final String itemId;

  /// A line on why this comes now, shown under the day.
  final String note;

  ContentItem get item => contentIndex.firstWhere((i) => i.id == itemId);
}

/// A guided path through a programme, one step a day. The tools already
/// exist; a course puts them in an order that builds, and gives a reason
/// to come back tomorrow.
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.blurb,
    required this.accent,
    required this.icon,
    required this.need,
    required this.days,
  });

  /// Stored with progress — never change these.
  final String id;
  final String title;
  final String blurb;
  final Color accent;
  final IconData icon;

  /// The need it's for, so goals can suggest it.
  final Need need;
  final List<CourseDay> days;
}

const courses = <Course>[
  Course(
    id: 'sleep7',
    title: '7 days to better sleep',
    blurb: 'Fix the evening first, then the night. A step a day.',
    accent: sleepAccent,
    icon: Icons.bedtime_rounded,
    need: Need.sleep,
    days: [
      CourseDay(
        'tool:Wind-down plan',
        'Sleep starts an hour before bed. Build the hour.',
      ),
      CourseDay(
        'lesson:Why you can\'t try harder to sleep',
        'Why effort keeps you awake, and what to do instead.',
      ),
      CourseDay(
        'tool:Put the day down',
        'Get tomorrow out of your head and onto paper.',
      ),
      CourseDay(
        'lesson:The 20-minute rule',
        'What to do when you\'ve been lying awake too long.',
      ),
      CourseDay(
        'breathing:4-7-8 calm',
        'A breath to slow the body down once you\'re in bed.',
      ),
      CourseDay(
        'lesson:Caffeine, alcohol and light',
        'The three things quietly shaping your nights.',
      ),
      CourseDay(
        'meditation:Sleep wind-down',
        'Put it all together: wind down, lie down, let go.',
      ),
    ],
  ),
  Course(
    id: 'anxiety7',
    title: '7 days with anxious thoughts',
    blurb: 'Steady yourself, then learn to catch and check the thoughts.',
    accent: cbtAccent,
    icon: Icons.psychology_rounded,
    need: Need.anxious,
    days: [
      CourseDay(
        'tool:Grounding: 5-4-3-2-1',
        'First, a way back into the room when it all gets loud.',
      ),
      CourseDay(
        'lesson:What CBT actually is',
        'How thoughts, feelings and actions feed each other.',
      ),
      CourseDay(
        'tool:Thinking traps',
        'The patterns anxious minds fall into, and their names.',
      ),
      CourseDay(
        'tool:Thought record',
        'Catch one thought and check it against the evidence.',
      ),
      CourseDay(
        'lesson:Why avoiding things keeps anxiety alive',
        'Why stepping back makes the next time harder.',
      ),
      CourseDay(
        'tool:Worry window',
        'Give worries a time, so they don\'t take the whole day.',
      ),
      CourseDay(
        'lesson:How to talk back to a thought',
        'Answering the thought, in your own voice.',
      ),
    ],
  ),
  Course(
    id: 'stress7',
    title: '7 days to lighter stress',
    blurb: 'Bring the body down, then sort what\'s on your plate.',
    accent: stressAccent,
    icon: Icons.speed_rounded,
    need: Need.stressed,
    days: [
      CourseDay(
        'tool:Physiological sigh',
        'The fastest way to downshift, for any moment.',
      ),
      CourseDay(
        'lesson:Stress isn\'t the enemy',
        'What stress is for, and when it tips over.',
      ),
      CourseDay(
        'tool:Stress check-in',
        'Where you are this week, so you can watch it change.',
      ),
      CourseDay(
        'tool:Tense and release',
        'Let go of what your muscles have been holding.',
      ),
      CourseDay(
        'lesson:Switching off the alarm',
        'How to tell your body the danger has passed.',
      ),
      CourseDay(
        'tool:What\'s in your hands',
        'Sort the load into control, influence and accept.',
      ),
      CourseDay(
        'tool:Recharge list',
        'What drains you, what refills you — and one refill today.',
      ),
    ],
  ),
];

/// The course that fits one of [goals], in goal order, if any.
Course? courseForGoals(Iterable<Need> goals) {
  for (final goal in goals) {
    for (final course in courses) {
      if (course.need == goal) return course;
    }
  }
  // Feeling low is closest to the anxious-thoughts course's tools.
  if (goals.contains(Need.low)) return courses[1];
  return null;
}
