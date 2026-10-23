/// Everything the app offers, in one list with shared tags: which needs
/// an item answers, how long it takes, the time of day it suits, and
/// whether it's free. Home's suggestions, Explore's "browse by need",
/// the collections and search all read from here, so content added to a
/// catalogue turns up in all of them at once.
library;

import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../billing/pricing_copy.dart';
import '../brand.dart';
import '../cbt/cbt_catalog.dart';
import '../cbt/cbt_content.dart';
import '../home/home_ui.dart';
import '../journal/journal_prompts.dart';
import '../journal/new_entry.dart';
import '../meditation/breathing_screen.dart';
import '../meditation/meditation_catalog.dart';
import '../meditation/meditation_screen.dart';
import '../practice/practice_repository.dart';
import '../recovery/halt_screen.dart';
import '../recovery/insights_screen.dart';
import '../recovery/milestones_screen.dart';
import '../recovery/recovery_screen.dart';
import '../recovery/tape_forward_screen.dart';
import '../sleep/sleep_catalog.dart';
import '../sleep/sleep_content.dart';
import '../sounds/player_screen.dart';
import '../sounds/sounds_catalog.dart';
import '../stress/stress_catalog.dart';
import '../stress/stress_content.dart';
import '../toolkit/toolkit_content.dart';
import '../toolkit/toolkit_lesson_screen.dart';
import 'content_tags.dart';
import 'usage_store.dart';

/// What someone might come to the app for. The order is the order of the
/// chips on Explore.
enum Need {
  sleep('Can\'t sleep', Icons.bedtime_rounded, Pillars.blue),
  anxious('Anxious', Icons.spa_rounded, Pillars.blue),
  panic('Panicking', Icons.air_rounded, Pillars.red),
  low('Feeling low', Icons.cloud_rounded, Pillars.black),
  stressed('Stressed', Icons.speed_rounded, Pillars.yellow),
  angry('Angry', Icons.local_fire_department_rounded, Pillars.red),
  urges('Urges', Icons.surfing_rounded, Pillars.black),
  focus('Focus', Icons.center_focus_strong_rounded, Pillars.yellow),
  reflect('Reflect', Icons.edit_note_rounded, Pillars.red),
  good('Feeling good', Icons.wb_sunny_rounded, Pillars.yellow);

  const Need(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  /// What the five check-in faces (awful → great) point towards.
  static Set<Need> forMood(int index) => switch (index) {
    0 => const {Need.panic, Need.anxious},
    1 => const {Need.low},
    2 => const {Need.reflect},
    _ => const {Need.good},
  };
}

/// Part of the day, for suggestions that fit the hour.
enum DayPart {
  morning('For this morning'),
  afternoon('For this afternoon'),
  evening('For this evening'),
  night('For tonight');

  const DayPart(this.heading);

  final String heading;

  static DayPart of(DateTime time) => switch (time.hour) {
    < 5 => night,
    < 12 => morning,
    < 17 => afternoon,
    < 21 => evening,
    _ => night,
  };
}

enum ContentKind {
  breathing('Breathing', Icons.air_rounded),
  meditation('Meditation', Icons.self_improvement_rounded),
  sound('Sound', Icons.graphic_eq_rounded),
  prompt('Journal prompt', Icons.edit_note_rounded),
  tool('Tool', Icons.handyman_rounded),
  lesson('Read', Icons.menu_book_rounded),
  recovery('Recovery', Icons.healing_rounded);

  const ContentKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// How long something takes, for the filter chips.
enum LengthFilter {
  any('Any length'),
  short('Under 5 min'),
  medium('5–10 min'),
  long('Over 10 min');

  const LengthFilter(this.label);

  final String label;

  /// Items with no set length (a prompt, a looping sound) only show under
  /// [any]: there's no honest way to sort them.
  bool matches(int? minutes) => switch (this) {
    any => true,
    short => minutes != null && minutes < 5,
    medium => minutes != null && minutes >= 5 && minutes <= 10,
    long => minutes != null && minutes > 10,
  };
}

/// One thing the app offers, and how to open it.
class ContentItem {
  const ContentItem({
    required this.kind,
    required this.title,
    required this.blurb,
    required this.icon,
    required this.accent,
    required this.premium,
    required this.open,
    this.minutes,
    this.area,
    this.needs = const {},
    this.dayParts = const {},
    this.addedOn,
  });

  final ContentKind kind;
  final String title;
  final String blurb;
  final IconData icon;
  final Color accent;
  final bool premium;

  /// Opens the item, once [openContent] has checked Premium.
  final void Function(BuildContext context) open;
  final int? minutes;

  /// The programme it belongs to ("CBT", "Sleep"), shown in place of the
  /// kind.
  final String? area;
  final Set<Need> needs;
  final Set<DayPart> dayParts;
  final DateTime? addedOn;

  String get id => '${kind.name}:$title';

  String get meta =>
      [area ?? kind.label, if (minutes != null) '$minutes min'].join(' · ');

  /// How long an item is badged "New" after it ships.
  static const newFor = Duration(days: 21);

  bool isNewAt(DateTime now) =>
      addedOn != null && now.difference(addedOn!) < newFor;
}

/// Checks Premium, notes the visit, then opens [item]. Every card that
/// opens content from the index comes through here, so none can slip
/// past the paywall.
///
/// Returns whether it opened, so a course can tick off a day only when the
/// day was actually started.
bool openContent(
  BuildContext context,
  ContentItem item, {
  required String source,
}) {
  final locked = item.premium && !isPremiumUser();
  // Which cards get tapped, from where: shows whether the suggestions,
  // needs and courses earn their place.
  Sentry.metrics.count(
    'content.opened',
    1,
    attributes: {
      'source': SentryAttribute.string(source),
      'kind': SentryAttribute.string(item.kind.name),
      'locked': SentryAttribute.string('$locked'),
    },
  );
  if (locked) {
    showUpgradeSheet(
      context,
      item: item.title,
      source: source,
      title: 'This is part of Premium',
      message:
          'Free includes a taste of everything. Premium unlocks every '
          'session, tool and read — and $introOffer.',
    );
    return false;
  }
  UsageStore.instance.recordOpen(item.kind);
  item.open(context);
  return true;
}

void _push(BuildContext context, WidgetBuilder builder) =>
    Navigator.of(context).push(MaterialPageRoute(builder: builder));

/// Tags an item gets from where it lives, before the table adds to them.
Set<Need> _soundNeeds(SoundCategory category) => switch (category) {
  SoundCategory.sleep => const {Need.sleep},
  SoundCategory.focus => const {Need.focus},
  SoundCategory.calm => const {Need.anxious, Need.stressed},
};

Set<Need> _promptNeeds(String group) => switch (group) {
  'Hard days' => const {Need.low, Need.reflect},
  'Recovery' => const {Need.urges},
  'Before sleep' => const {Need.sleep},
  _ => const {Need.reflect},
};

ContentItem _tagged(
  ContentItem item, {
  Set<Need> needs = const {},
  Set<DayPart> dayParts = const {},
}) {
  final tags = contentTags[item.id];
  final added = tags?.addedOn;
  return ContentItem(
    kind: item.kind,
    title: item.title,
    blurb: item.blurb,
    icon: item.icon,
    accent: item.accent,
    premium: item.premium,
    open: item.open,
    minutes: item.minutes,
    area: item.area,
    needs: {...needs, ...?tags?.needs},
    dayParts: {...dayParts, ...?tags?.dayParts},
    addedOn: added == null ? null : DateTime.parse(added),
  );
}

List<ContentItem> _toolkit(
  String area,
  Color accent,
  List<ToolkitTool> tools,
  List<ToolkitLesson> lessons, {
  Set<DayPart> dayParts = const {},
}) => [
  // A tool with a guard hands on to a meditation or breathing pattern
  // that's already in the index under its own name.
  for (final t in tools)
    if (t.guard == null)
      _tagged(
        ContentItem(
          kind: ContentKind.tool,
          title: t.title,
          blurb: t.blurb,
          icon: t.icon,
          accent: accent,
          premium: t.premium,
          minutes: t.minutes,
          area: area,
          open: (context) => _push(context, t.open),
        ),
        dayParts: dayParts,
      ),
  for (final l in lessons)
    _tagged(
      ContentItem(
        kind: ContentKind.lesson,
        title: l.title,
        blurb: l.blurb,
        icon: ContentKind.lesson.icon,
        accent: accent,
        premium: l.premium,
        minutes: l.minutes,
        area: '$area read',
        open: (context) => _push(
          context,
          (_) => ToolkitLessonScreen(lesson: l, accent: accent),
        ),
      ),
      dayParts: dayParts,
    ),
];

/// Built once from the real catalogues, so it covers exactly what the app
/// offers today.
final List<ContentItem> contentIndex = [
  for (final p in breathPatterns)
    _tagged(
      ContentItem(
        kind: ContentKind.breathing,
        title: p.title,
        blurb: p.detail,
        icon: Icons.air_rounded,
        accent: p.accent,
        premium: p.premium,
        minutes: 3,
        area: 'Breathing · ${p.rhythmLabel}',
        open: (context) => _push(context, (_) => BreathingScreen(pattern: p)),
      ),
    ),
  for (final m in meditations)
    _tagged(
      ContentItem(
        kind: ContentKind.meditation,
        title: m.title,
        blurb: m.detail,
        icon: m.icon,
        accent: m.accent,
        premium: m.premium,
        minutes: m.minutes,
        open: (context) =>
            _push(context, (_) => MeditationScreen(meditation: m)),
      ),
    ),
  for (final s in soundsCatalog)
    _tagged(
      ContentItem(
        kind: ContentKind.sound,
        title: s.title,
        blurb: s.detail,
        icon: s.icon,
        accent: s.category.accent,
        premium: s.premium,
        area: 'Sound · ${s.category.label}',
        open: (context) => _push(context, (_) => PlayerScreen(sound: s)),
      ),
      needs: _soundNeeds(s.category),
      dayParts: s.category == SoundCategory.sleep
          ? const {DayPart.night}
          : const {},
    ),
  for (final p in journalPrompts)
    _tagged(
      ContentItem(
        kind: ContentKind.prompt,
        title: p.title,
        blurb: p.detail,
        icon: p.icon,
        accent: p.accent,
        premium: p.premium,
        open: (context) =>
            openNewJournalEntry(context, title: p.title, content: p.seed),
      ),
      needs: _promptNeeds(p.group),
      dayParts: p.group == 'Before sleep' ? const {DayPart.evening} : const {},
    ),
  ..._toolkit('CBT', cbtAccent, cbtTools, cbtLessons),
  ..._toolkit('Sleep', sleepAccent, sleepTools, sleepLessons),
  ..._toolkit('Stress', stressAccent, stressTools, stressLessons),
  ..._recovery,
];

final _recovery = <ContentItem>[
  ContentItem(
    kind: ContentKind.recovery,
    title: urgeSurfMeditation.title,
    blurb: urgeSurfMeditation.detail,
    icon: urgeSurfMeditation.icon,
    accent: urgeSurfMeditation.accent,
    // The tool for the hardest minutes stays free.
    premium: false,
    minutes: urgeSurfMeditation.minutes,
    open: (context) => _push(
      context,
      (_) => const MeditationScreen(meditation: urgeSurfMeditation),
    ),
  ),
  ContentItem(
    kind: ContentKind.recovery,
    title: 'HALT check',
    blurb:
        'Hungry, angry, lonely, tired — find out what the craving is '
        'standing in for.',
    icon: Icons.psychology_alt_rounded,
    accent: Pillars.yellow,
    premium: true,
    open: (context) => _push(context, (_) => const HaltScreen()),
  ),
  ContentItem(
    kind: ContentKind.recovery,
    title: 'Play the tape forward',
    blurb: 'Watch the rest of the film before you decide.',
    icon: Icons.movie_filter_rounded,
    accent: Pillars.red,
    premium: true,
    open: (context) => _push(context, (_) => const TapeForwardScreen()),
  ),
  ContentItem(
    kind: ContentKind.recovery,
    title: 'Milestones',
    blurb: 'Every marker, reached and ahead, for each commitment.',
    icon: Icons.emoji_events_rounded,
    accent: Pillars.blue,
    premium: true,
    open: (context) => _push(context, (_) => const MilestonesScreen()),
  ),
  ContentItem(
    kind: ContentKind.recovery,
    title: 'Trigger insights',
    blurb: 'What sets cravings off, when they land, and how hard.',
    icon: Icons.query_stats_rounded,
    accent: Pillars.black,
    premium: true,
    open: (context) => _push(context, (_) => const TriggerInsightsScreen()),
  ),
  // Commitments and the trigger log live on the recovery hub itself,
  // which does its own gating.
  ContentItem(
    kind: ContentKind.recovery,
    title: 'My commitments',
    blurb: 'What you\'re leaving behind, and the days you\'ve kept.',
    icon: Icons.verified_rounded,
    accent: Pillars.blue,
    premium: false,
    open: (context) => _push(context, (_) => const RecoveryScreen()),
  ),
  ContentItem(
    kind: ContentKind.recovery,
    title: 'Trigger tracker',
    blurb: 'Log a craving: what set it off and how strong it was.',
    icon: Icons.bolt_rounded,
    accent: Pillars.yellow,
    premium: false,
    open: (context) => _push(context, (_) => const RecoveryScreen()),
  ),
].map((item) => _tagged(item, needs: const {Need.urges})).toList();

/// The index entry a finished practice session came from, for "continue".
ContentItem? contentForPractice(PracticeSession session) {
  final kinds = switch (session.kind) {
    PracticeKind.meditation => const [
      ContentKind.meditation,
      ContentKind.recovery,
    ],
    PracticeKind.breathing => const [ContentKind.breathing],
    PracticeKind.sound => const [ContentKind.sound],
  };
  for (final item in contentIndex) {
    if (kinds.contains(item.kind) && item.title == session.slug) return item;
  }
  return null;
}

/// Days since the epoch in local time: the seed that makes daily picks
/// change at midnight and stay put all day.
int dayNumber(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

/// Stable across runs, unlike [String.hashCode].
int _stableHash(String s) {
  var h = 0;
  for (final unit in s.codeUnits) {
    h = (h * 31 + unit) & 0x7fffffff;
  }
  return h;
}

/// Up to [count] items for [needs] and/or [dayPart], best match first.
///
/// For someone on the free plan, free items come first so a suggestion is
/// something they can actually open; Premium items fill any gap. Ties are
/// shuffled by the date, so suggestions change from day to day but not
/// between visits on the same day.
List<ContentItem> recommend({
  Set<Need> needs = const {},
  DayPart? dayPart,
  int count = 3,
  required DateTime now,
  required bool premium,
  Set<String> exclude = const {},
  List<ContentItem>? from,
  Set<Need> goals = const {},
  Map<ContentKind, double> kindBoost = const {},
}) {
  final day = dayNumber(now);
  // What makes an item eligible: the needs asked for, or the time of day.
  int match(ContentItem item) =>
      item.needs.intersection(needs).length * 2 +
      (dayPart != null && item.dayParts.contains(dayPart) ? 3 : 0);
  // What breaks ties among eligible items: the person's own goals, and
  // the kinds of practice they've said leave them feeling better.
  double score(ContentItem item) =>
      match(item) +
      item.needs.intersection(goals).length +
      (kindBoost[item.kind] ?? 0) * 2;
  final scored = [
    for (final item in from ?? contentIndex)
      if (!exclude.contains(item.id) && match(item) > 0) (item, score(item)),
  ];
  scored.sort((a, b) {
    if (!premium && a.$1.premium != b.$1.premium) {
      return a.$1.premium ? 1 : -1;
    }
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    return ((_stableHash(a.$1.id) + day * 7919) % 1009).compareTo(
      (_stableHash(b.$1.id) + day * 7919) % 1009,
    );
  });
  return [for (final (item, _) in scored.take(count)) item];
}

/// [FeelingStore.helpByKind] in index terms: a meditation that helps
/// boosts meditations (and the urge-surfing session, which is one).
Map<ContentKind, double> kindBoostFrom(Map<PracticeKind, double> help) => {
  if (help[PracticeKind.meditation] case final m?) ...{
    ContentKind.meditation: m,
    ContentKind.recovery: m / 2,
  },
  ContentKind.breathing: ?help[PracticeKind.breathing],
  ContentKind.sound: ?help[PracticeKind.sound],
};

/// Today's prompt or short read: the same all day, different tomorrow.
/// Free users rotate through what they can open.
ContentItem dailyPick({required DateTime now, required bool premium}) {
  final pool = [
    for (final item in contentIndex)
      if ((item.kind == ContentKind.prompt ||
              item.kind == ContentKind.lesson) &&
          (premium || !item.premium))
        item,
  ];
  return pool[dayNumber(now) % pool.length];
}

/// Free and Premium counts for a list of items: "1 free · 7 Premium", the
/// way the programme cards count.
String countLine(Iterable<ContentItem> items) {
  final locked = items.where((i) => i.premium).length;
  return '${items.length - locked} free · $locked Premium';
}
