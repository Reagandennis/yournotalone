/// The tags that sit on top of the catalogues. Each item already gets
/// sensible tags from where it lives (a sleep sound is for sleep, a
/// "Hard days" prompt is for low days — see `content_index.dart`); this
/// table adds what can't be guessed from that.
///
/// Adding content: put the item in its catalogue as usual, then add a line
/// here keyed `kind:Title` with the needs it answers, the times of day it
/// suits, and `addedOn` so Explore badges it "New" for a few weeks. A test
/// fails if a key here no longer matches a real item.
library;

import 'content_index.dart';

class ContentTags {
  const ContentTags(this.needs, {this.dayParts = const {}, this.addedOn});

  final Set<Need> needs;

  /// Empty means it suits any time of day.
  final Set<DayPart> dayParts;

  /// `YYYY-MM-DD`, the day it shipped.
  final String? addedOn;
}

const contentTags = <String, ContentTags>{
  // ── Breathing ──────────────────────────────────────────────────
  'breathing:Box breathing': ContentTags({
    Need.anxious,
    Need.stressed,
    Need.focus,
  }),
  'breathing:4-7-8 calm': ContentTags(
    {Need.sleep, Need.anxious},
    dayParts: {DayPart.evening, DayPart.night},
  ),
  'breathing:Slow exhale': ContentTags({Need.stressed, Need.angry}),
  'breathing:Coherent breath': ContentTags({Need.anxious, Need.focus}),
  'breathing:Ocean breath': ContentTags(
    {Need.sleep, Need.anxious},
    dayParts: {DayPart.night},
  ),
  'breathing:Triangle breath': ContentTags({Need.anxious, Need.angry}),
  'breathing:Panic reset': ContentTags({Need.panic, Need.anxious}),
  'breathing:Morning lift': ContentTags(
    {Need.low, Need.focus},
    dayParts: {DayPart.morning},
  ),

  // ── Meditations ────────────────────────────────────────────────
  'meditation:Morning grounding': ContentTags(
    {Need.anxious, Need.focus},
    dayParts: {DayPart.morning},
  ),
  'meditation:Anxiety relief': ContentTags({Need.anxious, Need.panic}),
  'meditation:Body scan': ContentTags(
    {Need.stressed, Need.sleep},
    dayParts: {DayPart.evening},
  ),
  'meditation:Sleep wind-down': ContentTags(
    {Need.sleep},
    dayParts: {DayPart.night},
  ),
  'meditation:Loving kindness': ContentTags({Need.low, Need.good}),
  'meditation:Midday reset': ContentTags(
    {Need.stressed, Need.focus},
    dayParts: {DayPart.afternoon},
  ),
  'meditation:Deep work focus': ContentTags(
    {Need.focus},
    dayParts: {DayPart.morning, DayPart.afternoon},
  ),
  'meditation:Self-compassion': ContentTags({Need.low}),
  'meditation:Letting go of anger': ContentTags({Need.angry}),
  'meditation:Walking meditation': ContentTags(
    {Need.low, Need.stressed},
    dayParts: {DayPart.afternoon},
  ),
  'meditation:Gratitude': ContentTags(
    {Need.good, Need.low},
    dayParts: {DayPart.evening},
  ),
  'meditation:Deep rest': ContentTags({Need.sleep}, dayParts: {DayPart.night}),

  // ── Sounds (category already tags sleep, focus or calm) ────────
  'sound:Heartbeat': ContentTags({Need.panic}),
  'sound:Breathe': ContentTags({Need.panic, Need.anxious}),
  'sound:Fireside': ContentTags({Need.low}, dayParts: {DayPart.evening}),

  // ── Journal prompts (group already tags most of them) ──────────
  'prompt:Gratitude': ContentTags({Need.good}, dayParts: {DayPart.evening}),
  'prompt:Let it out': ContentTags({Need.stressed, Need.angry}),
  'prompt:What I need': ContentTags({Need.low}),
  'prompt:Body check-in': ContentTags({Need.stressed}),
  'prompt:Worry dump': ContentTags({Need.anxious}),
  'prompt:After a panic': ContentTags({Need.panic}),
  'prompt:Anger on paper': ContentTags({Need.angry}),
  'prompt:Worst case': ContentTags({Need.anxious}),
  'prompt:Wins of the week': ContentTags({Need.good}),
  'prompt:Who showed up': ContentTags({Need.good}),
  'prompt:Tomorrow, gently': ContentTags({Need.anxious}),

  // ── CBT ────────────────────────────────────────────────────────
  'tool:Grounding: 5-4-3-2-1': ContentTags({Need.panic, Need.anxious}),
  'tool:Thought record': ContentTags({Need.anxious, Need.low}),
  'tool:Thinking traps': ContentTags({Need.anxious, Need.low}),
  'tool:One small thing': ContentTags({Need.low}, dayParts: {DayPart.morning}),
  'tool:Worry window': ContentTags({Need.anxious}),
  'tool:Problem solving': ContentTags({Need.stressed, Need.anxious}),
  'lesson:What CBT actually is': ContentTags({Need.anxious, Need.low}),
  'lesson:Why avoiding things keeps anxiety alive': ContentTags({Need.anxious}),
  'lesson:How to talk back to a thought': ContentTags({Need.anxious, Need.low}),

  // ── Sleep ──────────────────────────────────────────────────────
  'tool:Wind-down plan': ContentTags({Need.sleep}, dayParts: {DayPart.evening}),
  'tool:Put the day down': ContentTags(
    {Need.sleep, Need.anxious},
    dayParts: {DayPart.evening},
  ),
  'tool:Awake at 3am?': ContentTags({Need.sleep}, dayParts: {DayPart.night}),
  'tool:Sleep diary': ContentTags({Need.sleep}, dayParts: {DayPart.morning}),
  'tool:Sleep habits check': ContentTags({Need.sleep}),
  'lesson:Why you can\'t try harder to sleep': ContentTags({Need.sleep}),
  'lesson:The 20-minute rule': ContentTags({Need.sleep}),
  'lesson:Caffeine, alcohol and light': ContentTags({Need.sleep}),

  // ── Stress ─────────────────────────────────────────────────────
  'tool:Physiological sigh': ContentTags({
    Need.stressed,
    Need.panic,
    Need.angry,
  }),
  'tool:Tense and release': ContentTags(
    {Need.stressed, Need.sleep},
    dayParts: {DayPart.evening},
  ),
  'tool:Stress check-in': ContentTags({Need.stressed}),
  'tool:What\'s in your hands': ContentTags({Need.stressed, Need.anxious}),
  'tool:Recharge list': ContentTags(
    {Need.stressed, Need.low},
    dayParts: {DayPart.afternoon},
  ),
  'lesson:Stress isn\'t the enemy': ContentTags({Need.stressed}),
  'lesson:Switching off the alarm': ContentTags({Need.stressed, Need.panic}),
  'lesson:Running on empty': ContentTags({Need.stressed, Need.low}),

  // ── Recovery (all tagged for urges by default) ─────────────────
  'recovery:HALT check': ContentTags({Need.angry}),
};
