/// The words behind the CBT toolkit: thinking traps, activity ideas, short
/// lessons and the free resources we point people to. Kept apart from the
/// screens so the copy can be read and checked in one place.
library;

import 'package:flutter/material.dart';

import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_content.dart';

/// The toolkit's accent: the CBT card's red on Explore. This is the
/// declared colour: the header bar is filled with it as it is; text, icons
/// and lines draw it through `context.brand.accent`, washes through
/// `.tint`.
const cbtAccent = Color(0xFFC53C26);

/// A common unhelpful thinking pattern, with the question that loosens it.
class ThinkingTrap {
  const ThinkingTrap({
    required this.name,
    required this.soundsLike,
    required this.example,
    required this.ask,
    required this.icon,
  });

  final String name;

  /// How it tends to be worded in your head.
  final String soundsLike;
  final String example;

  /// The question to put to the thought.
  final String ask;
  final IconData icon;
}

const thinkingTraps = <ThinkingTrap>[
  ThinkingTrap(
    name: 'All-or-nothing',
    soundsLike: 'If it isn\'t perfect, it\'s a failure.',
    example: 'I ate one biscuit, so the whole day\'s ruined.',
    ask:
        'Where does this sit on a scale of 0 to 100, rather than pass '
        'or fail?',
    icon: Icons.contrast_rounded,
  ),
  ThinkingTrap(
    name: 'Catastrophising',
    soundsLike: 'What if the worst happens? It will.',
    example: 'She hasn\'t replied — something terrible has happened.',
    ask:
        'What\'s the most likely outcome, not the worst one? And if the '
        'worst did happen, how would I cope?',
    icon: Icons.thunderstorm_rounded,
  ),
  ThinkingTrap(
    name: 'Mind reading',
    soundsLike: 'I know what they\'re thinking about me.',
    example: 'He looked at his phone, so he thinks I\'m boring.',
    ask: 'What\'s my actual evidence? What else could explain it?',
    icon: Icons.psychology_rounded,
  ),
  ThinkingTrap(
    name: 'Fortune telling',
    soundsLike: 'I already know how this will go.',
    example: 'There\'s no point applying — I won\'t get it.',
    ask:
        'Have I predicted this before and been wrong? What would I '
        'lose by trying?',
    icon: Icons.auto_awesome_rounded,
  ),
  ThinkingTrap(
    name: 'Overgeneralising',
    soundsLike: 'This always happens. It never works out.',
    example: 'One bad date — I\'ll be alone forever.',
    ask: 'Always? Never? When has it gone differently?',
    icon: Icons.all_inclusive_rounded,
  ),
  ThinkingTrap(
    name: 'Mental filter',
    soundsLike: 'Only the bad bit counts.',
    example: 'Ten kind comments and one criticism — I only hear the one.',
    ask: 'If I widen the lens, what am I leaving out?',
    icon: Icons.filter_alt_rounded,
  ),
  ThinkingTrap(
    name: 'Discounting the positive',
    soundsLike: 'That doesn\'t count — anyone could have done it.',
    example: 'I got the job, but they were probably desperate.',
    ask: 'Would I let a friend brush this off? What did it actually take?',
    icon: Icons.thumb_down_off_alt_rounded,
  ),
  ThinkingTrap(
    name: 'Emotional reasoning',
    soundsLike: 'I feel it, so it must be true.',
    example: 'I feel like a burden, so I am one.',
    ask: 'Is a feeling the same as a fact? What would the facts say?',
    icon: Icons.favorite_border_rounded,
  ),
  ThinkingTrap(
    name: 'Should statements',
    soundsLike: 'I should. I must. I ought to.',
    example: 'I should be over this by now.',
    ask: 'Says who? What would "I\'d prefer to" sound like instead?',
    icon: Icons.rule_rounded,
  ),
  ThinkingTrap(
    name: 'Labelling',
    soundsLike: 'I\'m an idiot. They\'re a bad person.',
    example: 'I forgot her birthday — I\'m a terrible friend.',
    ask: 'Is that the whole person, or one thing that happened?',
    icon: Icons.label_rounded,
  ),
  ThinkingTrap(
    name: 'Personalising',
    soundsLike: 'It\'s my fault. It\'s about me.',
    example: 'The meeting went badly — because of what I said.',
    ask: 'What else was going on? How much of this was actually mine?',
    icon: Icons.person_pin_circle_rounded,
  ),
];

/// A small thing worth doing today, and what kind of lift it tends to give.
class ActivityIdea {
  const ActivityIdea(this.label, this.category);

  final String label;
  final ActivityCategory category;
}

enum ActivityCategory {
  connect('Connect', Icons.people_alt_rounded),
  move('Move', Icons.directions_walk_rounded),
  achieve('Achieve', Icons.task_alt_rounded),
  enjoy('Enjoy', Icons.wb_sunny_rounded),
  rest('Rest', Icons.self_improvement_rounded);

  const ActivityCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

const activityIdeas = <ActivityIdea>[
  ActivityIdea(
    'Message someone you\'ve been meaning to',
    ActivityCategory.connect,
  ),
  ActivityIdea('Call a friend or family member', ActivityCategory.connect),
  ActivityIdea(
    'Say hello to a neighbour or shopkeeper',
    ActivityCategory.connect,
  ),
  ActivityIdea('Sit with someone for a coffee', ActivityCategory.connect),
  ActivityIdea('Ten-minute walk outside', ActivityCategory.move),
  ActivityIdea('Stretch for five minutes', ActivityCategory.move),
  ActivityIdea('Dance to one song', ActivityCategory.move),
  ActivityIdea('Take the stairs, or walk one stop', ActivityCategory.move),
  ActivityIdea('Clear one surface', ActivityCategory.achieve),
  ActivityIdea(
    'Answer one email you\'ve been avoiding',
    ActivityCategory.achieve,
  ),
  ActivityIdea('Cook one proper meal', ActivityCategory.achieve),
  ActivityIdea('Pay a bill or make that appointment', ActivityCategory.achieve),
  ActivityIdea(
    'Listen to an album you love, start to finish',
    ActivityCategory.enjoy,
  ),
  ActivityIdea('Sit in the sun for ten minutes', ActivityCategory.enjoy),
  ActivityIdea('Read a chapter of something easy', ActivityCategory.enjoy),
  ActivityIdea('Water the plants, or buy one', ActivityCategory.enjoy),
  ActivityIdea('A shower, slowly', ActivityCategory.rest),
  ActivityIdea(
    'Ten minutes of breathing with the circle',
    ActivityCategory.rest,
  ),
  ActivityIdea(
    'Lie down with a calming sound, no phone',
    ActivityCategory.rest,
  ),
  ActivityIdea('In bed by a set time tonight', ActivityCategory.rest),
];

/// The five senses of the 5-4-3-2-1 grounding exercise, in order.
class GroundingStep {
  const GroundingStep(this.count, this.sense, this.prompt, this.icon);

  final int count;
  final String sense;
  final String prompt;
  final IconData icon;
}

const groundingSteps = <GroundingStep>[
  GroundingStep(
    5,
    'see',
    'Look around slowly. Name five things you can '
        'see — the smaller and more ordinary, the better.',
    Icons.visibility_rounded,
  ),
  GroundingStep(
    4,
    'feel',
    'Four things you can feel: your feet on the '
        'floor, the fabric of your sleeve, the air on your face.',
    Icons.back_hand_rounded,
  ),
  GroundingStep(
    3,
    'hear',
    'Three sounds. Let the faraway ones in too.',
    Icons.hearing_rounded,
  ),
  GroundingStep(
    2,
    'smell',
    'Two things you can smell — or two smells you '
        'like, if there\'s nothing here.',
    Icons.air_rounded,
  ),
  GroundingStep(
    1,
    'taste',
    'One thing you can taste. A sip of water counts.',
    Icons.local_cafe_rounded,
  ),
];

const cbtLessons = <ToolkitLesson>[
  ToolkitLesson(
    title: 'What CBT actually is',
    blurb:
        'Thoughts, feelings and actions pull on each other. That\'s the '
        'whole idea.',
    minutes: 3,
    art: ToolkitArtKind.learn,
    premium: false,
    paragraphs: [
      'Cognitive behavioural therapy starts from one observation: how we '
          'feel depends less on what happens to us than on what we make of '
          'it. Two people miss the same bus. One thinks "typical, nothing '
          'goes right for me" and feels flat for an hour. The other thinks '
          '"annoying — I\'ll message ahead" and moves on. Same bus.',
      'The thoughts that shape our mood are usually quick, automatic and '
          'unexamined. CBT teaches you to notice them, check them against '
          'the evidence, and answer them — not with forced positivity, but '
          'with something fairer and more accurate.',
      'The other half is behaviour. When we feel low we do less; doing less '
          'gives us less to feel good about; so we feel lower. Anxiety works '
          'the same way through avoidance. Changing what you do, even a '
          'little, changes how you feel — often before your thinking '
          'catches up.',
      'None of this is a trick. It\'s a set of skills, and like any skill '
          'it works with practice. The tools in this section are the ones '
          'therapists teach most often. Use them alongside a session, or '
          'on their own.',
    ],
  ),
  ToolkitLesson(
    title: 'Why avoiding things keeps anxiety alive',
    blurb: 'Avoidance feels like relief. It\'s actually the fuel.',
    minutes: 2,
    art: ToolkitArtKind.traps,
    paragraphs: [
      'When something frightens you and you step away from it, the fear '
          'drops. That drop is a reward, and your brain learns from it: '
          '"avoiding worked". Next time the pull to avoid is stronger, and '
          'the thing itself never gets the chance to turn out fine.',
      'The way out is the opposite, done gently: approach the feared thing '
          'in steps small enough to manage, stay long enough for the fear to '
          'come down on its own, and repeat. Each time, your brain updates. '
          'This is called graded exposure, and it is one of the most '
          'reliable findings in all of psychology.',
      'You don\'t have to do it alone or all at once. Write the steps down, '
          'start with one that\'s uncomfortable but doable, and treat each '
          'one as an experiment: "what do I predict will happen — and what '
          'actually happened?"',
    ],
  ),
  ToolkitLesson(
    title: 'How to talk back to a thought',
    blurb: 'Not "think positive". Think accurately.',
    minutes: 2,
    art: ToolkitArtKind.thoughts,
    paragraphs: [
      'A balanced thought isn\'t the cheerful opposite of the anxious one. '
          '"I\'ll definitely fail" doesn\'t become "I\'ll definitely '
          'succeed". It becomes something you could actually defend in '
          'front of a fair judge: "I\'m underprepared for part of this, '
          'I\'ve passed harder things, and if it goes badly I can retake '
          'it."',
      'Three questions do most of the work. What is the evidence for this '
          'thought, and against it? What would I say to a friend who told '
          'me this? And: is there a thinking trap in here — am I mind '
          'reading, catastrophising, filtering out the good?',
      'Write it down. Thoughts that stay in your head keep their weight; '
          'on paper they\'re just sentences, and sentences can be checked. '
          'That\'s what the thought record is for.',
    ],
  ),
];

const cbtResources = <ToolkitResource>[
  ToolkitResource(
    title: 'Looking After Yourself workbooks',
    by: 'Centre for Clinical Interventions, Western Australia',
    blurb:
        'Full CBT workbooks on depression, worry, panic, perfectionism, '
        'self-esteem and more — free PDFs written by clinicians.',
    url: 'https://www.cci.health.wa.gov.au/Resources/Looking-After-Yourself',
  ),
  ToolkitResource(
    title: 'Every Mind Matters',
    by: 'NHS, United Kingdom',
    blurb:
        'Plain-language self-help for anxiety, low mood, sleep and '
        'stress, with short video guides to CBT techniques.',
    url: 'https://www.nhs.uk/every-mind-matters/',
  ),
  ToolkitResource(
    title: 'Get Self Help',
    by: 'Carol Vivyan, cognitive behavioural therapist',
    blurb:
        'Hundreds of free CBT worksheets and information sheets — the '
        'same ones many therapists print out for clients.',
    url: 'https://www.getselfhelp.co.uk/',
  ),
  ToolkitResource(
    title: 'MoodGYM',
    by: 'Australian National University',
    blurb:
        'A structured online CBT programme for depression and anxiety, '
        'shown in trials to help. Free registration.',
    url: 'https://moodgym.com.au/',
  ),
  ToolkitResource(
    title: 'Befrienders Worldwide',
    by: 'Befrienders Worldwide',
    blurb:
        'Emotional-support helplines in more than 30 countries, for when '
        'a worksheet isn\'t enough and you need a person.',
    url: 'https://befrienders.org/',
  ),
];
