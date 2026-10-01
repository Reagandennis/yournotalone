/// The words behind the sleep programme: habits to check, the wind-down
/// steps, short reads and the free resources we point people to. Kept
/// apart from the screens so the copy can be read in one place.
library;

import 'package:flutter/material.dart';

import '../toolkit/toolkit_art.dart';
import '../toolkit/toolkit_content.dart';

/// The programme's accent: the sleep card's blue on Explore.
const sleepAccent = Color(0xFF3E6AB7);

/// One habit the sleep check asks about. A "yes" is the unhelpful answer,
/// and [tip] is what to do about it.
class SleepHabit {
  const SleepHabit(this.id, this.question, this.tip, this.icon);

  final String id;
  final String question;
  final String tip;
  final IconData icon;
}

const sleepHabits = <SleepHabit>[
  SleepHabit(
    'wake',
    'Does your wake-up time move by more than an hour '
        'between days?',
    'A fixed wake time, weekends included, is the single '
        'most powerful lever on sleep. Bedtime can move; the alarm shouldn\'t.',
    Icons.alarm_rounded,
  ),
  SleepHabit(
    'caffeine',
    'Do you have caffeine after about 2pm?',
    'Caffeine '
        'has a half-life of five to six hours. A 4pm coffee is still a '
        'quarter of a coffee at midnight. Move the last one to lunchtime.',
    Icons.coffee_rounded,
  ),
  SleepHabit(
    'screens',
    'Do you use your phone or a laptop in bed?',
    'It\'s '
        'less the blue light than the wakefulness: the scrolling, the '
        'messages, the news. Charge the phone across the room.',
    Icons.phone_iphone_rounded,
  ),
  SleepHabit(
    'naps',
    'Do you nap for more than 20 minutes, or after 3pm?',
    'Long or late naps spend the sleep pressure you need at night. Keep '
        'naps to twenty minutes, before mid-afternoon — or skip them.',
    Icons.hotel_rounded,
  ),
  SleepHabit(
    'alcohol',
    'Do you drink alcohol in the evening to help you '
        'sleep?',
    'Alcohol knocks you out and then wakes you up: it wrecks '
        'the second half of the night. Two alcohol-free evenings a week is a '
        'fair first experiment.',
    Icons.wine_bar_rounded,
  ),
  SleepHabit(
    'clock',
    'Do you check the time when you wake in the night?',
    'Every glance at the clock is a small maths problem and a small '
        'panic. Turn it to the wall. What time it is changes nothing you can '
        'do.',
    Icons.schedule_rounded,
  ),
  SleepHabit(
    'bed',
    'Do you lie in bed awake for long stretches, hoping?',
    'The bed should mean sleep, not struggle. Awake for what feels like '
        '20 minutes? Get up, dim light, something dull, back when sleepy.',
    Icons.bed_rounded,
  ),
  SleepHabit(
    'exercise',
    'Do you exercise hard within two hours of bed?',
    'Movement earlier in the day deepens sleep; hard effort late in the '
        'evening raises your temperature and heart rate right when they '
        'should be falling.',
    Icons.fitness_center_rounded,
  ),
  SleepHabit(
    'room',
    'Is your bedroom warm, bright or noisy at night?',
    'Cool '
        '(around 18°C), dark and quiet. Blackout curtains, an eye mask and '
        'earplugs are cheap for what they give back.',
    Icons.thermostat_rounded,
  ),
  SleepHabit(
    'lie_in',
    'Do you sleep in to catch up after a bad night?',
    'A '
        'lie-in feels like repair but it pushes the next night later. Get up '
        'at the usual time; tonight\'s sleep pressure will be stronger for it.',
    Icons.wb_twilight_rounded,
  ),
];

/// One step of the wind-down, counted back from bedtime.
class WindDownStep {
  const WindDownStep(
    this.id,
    this.minutesBefore,
    this.title,
    this.detail,
    this.icon,
  );

  final String id;
  final int minutesBefore;
  final String title;
  final String detail;
  final IconData icon;
}

const windDownSteps = <WindDownStep>[
  WindDownStep(
    'screens',
    60,
    'Screens down, lights low',
    'Last look at '
        'messages and news. Dim the main lights; lamps only from here.',
    Icons.light_mode_rounded,
  ),
  WindDownStep(
    'tomorrow',
    45,
    'Put the day down',
    'Write tomorrow\'s three '
        'things and one thing you\'re letting go. Then it\'s on paper, not '
        'in your head.',
    Icons.edit_note_rounded,
  ),
  WindDownStep(
    'body',
    30,
    'Warm shower or a stretch',
    'Warmth then cooling '
        'tells the body it\'s night. Ten slow minutes is enough.',
    Icons.shower_rounded,
  ),
  WindDownStep(
    'quiet',
    15,
    'Something quiet and unexciting',
    'A book you\'ve '
        'read before. A calm sound. Not the gripping thing.',
    Icons.menu_book_rounded,
  ),
  WindDownStep(
    'breathe',
    5,
    'Breathe, lights off',
    'Ten rounds of 4-7-8 or '
        'slow exhale in the dark. Then let sleep come to you.',
    Icons.air_rounded,
  ),
];

const sleepLessons = <ToolkitLesson>[
  ToolkitLesson(
    title: 'Why you can\'t try harder to sleep',
    blurb: 'Sleep is something that happens to you, not something you do.',
    minutes: 3,
    art: ToolkitArtKind.moon,
    premium: false,
    paragraphs: [
      'Two things decide whether you fall asleep: how much sleep pressure '
          'has built up since you last slept, and how switched on your '
          'nervous system is. Pressure you can only build by being awake '
          'and active. Arousal you can only lower — by winding down, by '
          'not fighting.',
      'Effort is arousal. Lying there commanding yourself to sleep raises '
          'exactly the thing that keeps you awake. This is why the harder '
          'you try, the worse it goes, and why people often sleep best on '
          'the sofa, where they weren\'t trying at all.',
      'So the work of sleeping better happens in the daytime and the hour '
          'before bed, not in bed. Get up at the same time. Be active. Let '
          'the evening dim. Get out of bed when you\'re wide awake. Then '
          'trust the pressure you\'ve built to do the rest.',
      'One bad night proves nothing. Bodies are good at catching up on '
          'their own if you don\'t interfere — the deep sleep comes first '
          'the next night. The thing to protect isn\'t tonight; it\'s the '
          'routine.',
    ],
  ),
  ToolkitLesson(
    title: 'The 20-minute rule',
    blurb: 'Your bed should mean sleep. Lying awake teaches it otherwise.',
    minutes: 2,
    art: ToolkitArtKind.awake,
    paragraphs: [
      'Brains learn by association. If you spend hours in bed frustrated, '
          'awake and worrying, the bed itself starts to trigger frustration '
          'and wakefulness — you feel sleepy on the sofa and alert the '
          'moment your head hits the pillow. Insomnia specialists call the '
          'cure stimulus control, and it\'s the most reliable technique '
          'they have.',
      'The rule: if you\'ve been awake for what feels like twenty minutes, '
          'get up. Go to another room, keep the lights low, and do something '
          'quiet and dull until you feel sleepy — actually sleepy, not just '
          'tired of being up. Then go back. Repeat as often as it takes.',
      'It feels counterproductive for the first week; you\'ll be up more '
          'and sleep less. By the second or third week the bed means sleep '
          'again, and you fall asleep faster than you have in years. Keep '
          'your wake time fixed throughout, or it doesn\'t work.',
    ],
  ),
  ToolkitLesson(
    title: 'Caffeine, alcohol and light',
    blurb: 'Three levers you can move today, and when to move them.',
    minutes: 2,
    art: ToolkitArtKind.windDown,
    paragraphs: [
      'Caffeine blocks the chemical that carries sleep pressure. Its '
          'half-life is five to six hours, so a coffee at four is a quarter '
          'coffee at midnight. If you sleep badly, make the last one before '
          'two.',
      'Alcohol is a sedative and then a stimulant. It helps you drop off '
          'and then fragments the second half of the night, cutting the '
          'dreaming sleep that does the emotional housekeeping. If you use '
          'it to sleep, you\'re borrowing from three a.m.',
      'Light is the clock. Bright light in the morning — outdoors, even on '
          'a grey day — pulls your body clock earlier and makes the evening '
          'come sooner. Bright light late does the opposite. Ten minutes '
          'outside before nine a.m. and dim lamps after nine p.m. is the '
          'whole prescription.',
    ],
  ),
];

const sleepResources = <ToolkitResource>[
  ToolkitResource(
    title: 'Sleep workbook',
    by: 'Centre for Clinical Interventions, Western Australia',
    blurb:
        'A free, clinician-written CBT for insomnia course in short '
        'modules: sleep restriction, stimulus control, unhelpful beliefs.',
    url:
        'https://www.cci.health.wa.gov.au/Resources/Looking-After-Yourself/Sleep',
  ),
  ToolkitResource(
    title: 'How to fall asleep faster and sleep better',
    by: 'NHS Every Mind Matters, United Kingdom',
    blurb:
        'Plain-language sleep advice with short videos, plus a free '
        'email programme of daily tips.',
    url:
        'https://www.nhs.uk/every-mind-matters/mental-wellbeing-tips/how-to-fall-asleep-faster-and-sleep-better/',
  ),
  ToolkitResource(
    title: 'CBT-i Coach',
    by: 'US Department of Veterans Affairs',
    blurb:
        'A free app built to go alongside CBT for insomnia: sleep diary, '
        'sleep-window prescription, wind-down tools. Anyone can use it.',
    url: 'https://mobile.va.gov/app/cbt-i-coach',
  ),
  ToolkitResource(
    title: 'Printable sleep diary',
    by: 'Sleep Foundation',
    blurb:
        'A printable two-week diary if you\'d rather keep it on paper, '
        'and a guide to what the numbers mean.',
    url: 'https://www.sleepfoundation.org/sleep-diary',
  ),
];
