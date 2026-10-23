import 'package:flutter/material.dart';

import '../brand.dart';
import '../practice/feeling_store.dart';
import '../practice/practice_repository.dart';
import 'mood_repository.dart';

/// One thing the numbers say, in plain words.
class Insight {
  const Insight(this.icon, this.color, this.title, this.detail);

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
}

const _weekdays = [
  'Mondays',
  'Tuesdays',
  'Wednesdays',
  'Thursdays',
  'Fridays',
  'Saturdays',
  'Sundays',
];

/// Mood score 1–5 from a check-in.
double _score(MoodEntry e) => e.index + 1.0;

double _mean(Iterable<double> xs) => xs.reduce((a, b) => a + b) / xs.length;

/// What the last ninety days of check-ins, practice and post-session
/// answers add up to. Pure, so the maths can be tested on its own; each
/// insight only appears once there's enough behind it to be honest.
List<Insight> moodInsights({
  required List<MoodEntry> moods,
  required List<PracticeSession> sessions,
  required List<FeelingRecord> feelings,
  required DateTime now,
}) {
  final insights = <Insight>[];
  final today = DateUtils.dateOnly(now);

  // Check-ins this month, and the run of days up to today.
  final thisMonth = moods
      .where((e) => e.date.year == now.year && e.date.month == now.month)
      .length;
  final checked = {for (final e in moods) DateUtils.dateOnly(e.date)};
  var streak = 0;
  for (var back = 0; back < 120; back++) {
    final day = DateTime(today.year, today.month, today.day - back);
    if (!checked.contains(day)) {
      if (back == 0) continue; // today isn't over
      break;
    }
    streak++;
  }
  if (thisMonth > 0) {
    insights.add(
      Insight(
        Icons.calendar_month_rounded,
        Pillars.blue,
        'You\'ve checked in $thisMonth '
        '${thisMonth == 1 ? 'day' : 'days'} this month',
        streak > 1
            ? 'That\'s $streak days in a row right now. Noticing is where '
                  'change starts.'
            : 'Every check-in makes the picture clearer.',
      ),
    );
  }

  // Mood on days with practice against days without.
  final practised = {
    for (final s in sessions) DateUtils.dateOnly(s.completedAt),
  };
  final onDays = [
    for (final e in moods)
      if (practised.contains(DateUtils.dateOnly(e.date))) _score(e),
  ];
  final offDays = [
    for (final e in moods)
      if (!practised.contains(DateUtils.dateOnly(e.date))) _score(e),
  ];
  if (onDays.length >= 3 && offDays.length >= 3) {
    final diff = _mean(onDays) - _mean(offDays);
    if (diff >= 0.3) {
      insights.add(
        const Insight(
          Icons.self_improvement_rounded,
          Pillars.blue,
          'Your mood is higher on days you practise',
          'Days with a meditation, breathing or a sound score better than '
              'days without. Worth keeping a small daily habit.',
        ),
      );
    } else if (diff <= -0.3) {
      insights.add(
        const Insight(
          Icons.self_improvement_rounded,
          Pillars.yellow,
          'You tend to practise on harder days',
          'Your practice days have lower moods — which may mean you reach '
              'for it when you need it. That\'s what it\'s for.',
        ),
      );
    } else {
      insights.add(
        const Insight(
          Icons.self_improvement_rounded,
          Pillars.black,
          'Practice days and other days look alike so far',
          'Keep checking in — the pattern gets clearer with a few more weeks.',
        ),
      );
    }
  }

  // The hardest and easiest days of the week.
  if (moods.length >= 10) {
    final byDay = <int, List<double>>{};
    for (final e in moods) {
      (byDay[e.date.weekday] ??= []).add(_score(e));
    }
    final ranked = [
      for (final entry in byDay.entries)
        if (entry.value.length >= 2) (entry.key, _mean(entry.value)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    if (ranked.length >= 3 && ranked.last.$2 - ranked.first.$2 >= 0.5) {
      insights.add(
        Insight(
          Icons.event_rounded,
          Pillars.red,
          '${_weekdays[ranked.first.$1 - 1]} are usually your hardest days',
          '${_weekdays[ranked.last.$1 - 1]} tend to go best. A little '
              'something planned for ${_weekdays[ranked.first.$1 - 1].toLowerCase()} '
              'could help.',
        ),
      );
    }
  }

  // The last two weeks against the two before.
  final recent = [
    for (final e in moods)
      if (today.difference(DateUtils.dateOnly(e.date)).inDays < 14) _score(e),
  ];
  final before = [
    for (final e in moods)
      if (today.difference(DateUtils.dateOnly(e.date)).inDays >= 14 &&
          today.difference(DateUtils.dateOnly(e.date)).inDays < 28)
        _score(e),
  ];
  if (recent.length >= 4 && before.length >= 4) {
    final diff = _mean(recent) - _mean(before);
    if (diff >= 0.4) {
      insights.add(
        const Insight(
          Icons.trending_up_rounded,
          Pillars.blue,
          'The last two weeks have been better',
          'Your check-ins are up on the fortnight before. Whatever you\'re '
              'doing, it\'s worth noticing.',
        ),
      );
    } else if (diff <= -0.4) {
      insights.add(
        const Insight(
          Icons.trending_down_rounded,
          Pillars.red,
          'The last two weeks have been harder',
          'Your check-ins are down on the fortnight before. Be gentle with '
              'yourself — and talking to someone can help.',
        ),
      );
    }
  }

  // What the post-session answers say.
  final line = FeelingStore.summarise(feelings).line;
  if (line != null) {
    insights.add(
      Insight(
        Icons.favorite_rounded,
        Pillars.red,
        line,
        'From how you said you felt at the end of each session.',
      ),
    );
  }

  return insights;
}
