/// The words behind the stress programme: the check-in questions, the
/// muscle groups, the recharge ideas, short reads and free resources.
library;

import 'package:flutter/material.dart';

import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_content.dart';

/// The programme's accent: the stress card's yellow on Explore.
const stressAccent = Color(0xFFF4BB40);

/// One question of the weekly stress check-in, answered 0 (never) to 4
/// (very often). [reversed] items describe coping, so they count the
/// other way.
class StressQuestion {
  const StressQuestion(this.text, {this.reversed = false});

  final String text;
  final bool reversed;
}

/// Five questions in the spirit of the perceived-stress scales used in
/// research, written in our own words. A guide, not a diagnosis.
const stressQuestions = <StressQuestion>[
  StressQuestion(
    'How often have you felt that things were piling up '
    'faster than you could deal with them?',
  ),
  StressQuestion(
    'How often have you felt unable to control the important '
    'things in your life?',
  ),
  StressQuestion(
    'How often have you felt confident about handling your '
    'personal problems?',
    reversed: true,
  ),
  StressQuestion(
    'How often have you felt that things were going your '
    'way?',
    reversed: true,
  ),
  StressQuestion('How often have you felt nervous, wound up or on edge?'),
];

const stressAnswers = ['Never', 'Rarely', 'Sometimes', 'Often', 'Very often'];

/// One muscle group in progressive muscle relaxation, in the order the
/// exercise works through the body.
class MuscleGroup {
  const MuscleGroup(this.name, this.tense, this.icon);

  final String name;

  /// How to tense it.
  final String tense;
  final IconData icon;
}

const muscleGroups = <MuscleGroup>[
  MuscleGroup('Hands', 'Make two tight fists.', Icons.back_hand_rounded),
  MuscleGroup(
    'Arms',
    'Bend your elbows and squeeze your biceps.',
    Icons.fitness_center_rounded,
  ),
  MuscleGroup(
    'Shoulders',
    'Pull them up towards your ears.',
    Icons.expand_less_rounded,
  ),
  MuscleGroup(
    'Face',
    'Screw everything up — eyes, jaw, forehead.',
    Icons.face_rounded,
  ),
  MuscleGroup(
    'Chest and belly',
    'Breathe in and hold, tightening your stomach.',
    Icons.favorite_rounded,
  ),
  MuscleGroup(
    'Back',
    'Gently arch it, squeezing the shoulder blades together.',
    Icons.airline_seat_recline_normal_rounded,
  ),
  MuscleGroup(
    'Legs',
    'Straighten them and tense the thighs.',
    Icons.directions_walk_rounded,
  ),
  MuscleGroup('Feet', 'Curl your toes down hard.', Icons.do_not_step_rounded),
];

/// Things that fill the tank, by kind.
class RechargeIdea {
  const RechargeIdea(this.label, this.icon);

  final String label;
  final IconData icon;
}

const rechargeIdeas = <RechargeIdea>[
  RechargeIdea('A walk with no phone', Icons.directions_walk_rounded),
  RechargeIdea(
    'Twenty minutes of something with your hands',
    Icons.handyman_rounded,
  ),
  RechargeIdea('A proper lunch, away from the desk', Icons.restaurant_rounded),
  RechargeIdea('A call with someone who makes you laugh', Icons.call_rounded),
  RechargeIdea('An early night', Icons.bedtime_rounded),
  RechargeIdea('Music, loud, for one song', Icons.music_note_rounded),
  RechargeIdea('Ten minutes outside in daylight', Icons.wb_sunny_rounded),
  RechargeIdea('Saying no to one thing this week', Icons.block_rounded),
  RechargeIdea('A shower and clean clothes', Icons.shower_rounded),
  RechargeIdea(
    'Doing nothing, on purpose, for five minutes',
    Icons.self_improvement_rounded,
  ),
];

const stressLessons = <ToolkitLesson>[
  ToolkitLesson(
    title: 'Stress isn\'t the enemy',
    blurb: 'The problem is never the surge. It\'s the missing recovery.',
    minutes: 3,
    art: ToolkitArtKind.gauge,
    premium: false,
    paragraphs: [
      'The stress response is a piece of good engineering. Heart rate up, '
          'attention narrowed, fuel released: it\'s what lets you swerve a '
          'car, meet a deadline, give the speech. Short bursts followed by '
          'rest leave you no worse off — sometimes better. Athletes call '
          'this training.',
      'The damage comes when the surge never ends. Deadlines that roll into '
          'deadlines, worry that fills the evenings, sleep that doesn\'t '
          'restore. The body stays in gear, and gear that\'s never released '
          'wears: poor sleep, a short fuse, a stomach that complains, '
          'getting every cold going.',
      'So the question isn\'t "how do I have less stress" — often you '
          'can\'t. It\'s "where is my recovery". Recovery is anything that '
          'tells the body the emergency is over: a long exhale, movement, '
          'laughter, food eaten slowly, a person you trust, sleep. Not '
          'scrolling; that\'s more input.',
      'The tools here work on both sides: some cut the load, most add '
          'recovery. Ten deliberate minutes of recovery a day changes the '
          'arithmetic more than people expect.',
    ],
  ),
  ToolkitLesson(
    title: 'Switching off the alarm',
    blurb: 'You can\'t think your way calm. You can breathe your way there.',
    minutes: 2,
    art: ToolkitArtKind.sigh,
    paragraphs: [
      'The part of you that panics doesn\'t read. Telling yourself to calm '
          'down works about as well as telling a smoke alarm to calm down. '
          'What that part does respond to is the body: the breath, the '
          'muscles, movement.',
      'The exhale is the lever. Breathing out slows the heart a little; '
          'breathing in speeds it up. Make the out-breath longer than the '
          'in-breath and, within a minute or two, the alarm quietens on its '
          'own. The physiological sigh — two sips in, one long breath out — '
          'is the fastest version anyone has measured.',
      'Muscles work the same way in reverse. A tense body tells the brain '
          'there\'s a threat. Tensing hard and then letting go, group by '
          'group, sends the opposite message, and most people feel it '
          'within a single round.',
      'Do these before you think. Once the alarm is quieter, thinking '
          'works again — and the problem-solving tools have something to '
          'work with.',
    ],
  ),
  ToolkitLesson(
    title: 'Running on empty',
    blurb: 'How to tell tired from burnt out, and what to do about each.',
    minutes: 3,
    art: ToolkitArtKind.battery,
    paragraphs: [
      'Tired gets better with rest. Burnout doesn\'t, or not quickly: a '
          'weekend off and Monday feels the same. The other marks are '
          'cynicism — caring less about things you used to care about — and '
          'a sense that nothing you do makes a difference. Together, over '
          'months, those three are the picture.',
      'It usually comes from a mismatch that lasts: more asked than you can '
          'give, less control than you need, effort that isn\'t seen, or '
          'work that grinds against what you value. Sleep and breathing '
          'help you carry it; they don\'t fix the mismatch. That takes a '
          'conversation, a boundary, or a change.',
      'If this is you, three moves. Name it to one person. Cut one thing — '
          'actually cut, not postpone. And talk to someone whose job it is: '
          'a GP, or a therapist. Burnout in its later stages looks a lot '
          'like depression, and it deserves the same seriousness.',
      'If you\'re having thoughts of not wanting to be here, that\'s '
          'beyond this app. Use Get help now on the Home screen, today.',
    ],
  ),
];

const stressResources = <ToolkitResource>[
  ToolkitResource(
    title: 'Doing What Matters in Times of Stress',
    by: 'World Health Organization',
    blurb:
        'An illustrated, five-part guide to grounding, unhooking from '
        'difficult thoughts and acting on your values. Free, in many '
        'languages.',
    url: 'https://www.who.int/publications/i/item/9789240003927',
  ),
  ToolkitResource(
    title: 'Stress',
    by: 'NHS Every Mind Matters, United Kingdom',
    blurb:
        'Signs to watch for, a short self-assessment, and practical '
        'steps for work, money and relationship stress.',
    url: 'https://www.nhs.uk/every-mind-matters/mental-health-issues/stress/',
  ),
  ToolkitResource(
    title: 'Managing stress',
    by: 'Mind, United Kingdom',
    blurb:
        'What stress does to you, how to spot when it\'s tipping into '
        'something more, and where to get support.',
    url:
        'https://www.mind.org.uk/information-support/types-of-mental-health-problems/stress/',
  ),
  ToolkitResource(
    title: 'Stress management',
    by: 'HelpGuide',
    blurb:
        'Clear, evidence-based articles on the four As — avoid, alter, '
        'adapt, accept — and on burnout recovery.',
    url: 'https://www.helpguide.org/mental-health/stress/stress-management',
  ),
];
