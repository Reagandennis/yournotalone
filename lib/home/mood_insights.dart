import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
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

/// [DateTime.weekday] (1 is Monday) as the key the weekday messages
/// select on.
const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Mood score 1–5 from a check-in.
double _score(MoodEntry e) => e.index + 1.0;

double _mean(Iterable<double> xs) => xs.reduce((a, b) => a + b) / xs.length;

/// What the last ninety days of check-ins, practice and post-session
/// answers add up to. Pure, so the maths can be tested on its own; each
/// insight only appears once there's enough behind it to be honest.
/// Worded in [l10n]'s language, English if not given.
List<Insight> moodInsights({
  required List<MoodEntry> moods,
  required List<PracticeSession> sessions,
  required List<FeelingRecord> feelings,
  required DateTime now,
  AppLocalizations? l10n,
}) {
  final l = l10n ?? lookupAppLocalizations(const Locale('en'));
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
        l.moodInsightCheckedInTitle(thisMonth),
        streak > 1
            ? l.moodInsightCheckedInStreak(streak)
            : l.moodInsightCheckedInFirst,
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
        Insight(
          Icons.self_improvement_rounded,
          Pillars.blue,
          l.moodInsightPracticeHigherTitle,
          l.moodInsightPracticeHigherDetail,
        ),
      );
    } else if (diff <= -0.3) {
      insights.add(
        Insight(
          Icons.self_improvement_rounded,
          Pillars.yellow,
          l.moodInsightPracticeLowerTitle,
          l.moodInsightPracticeLowerDetail,
        ),
      );
    } else {
      insights.add(
        Insight(
          Icons.self_improvement_rounded,
          Pillars.black,
          l.moodInsightPracticeSameTitle,
          l.moodInsightPracticeSameDetail,
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
      final hardest = _weekdayKeys[ranked.first.$1 - 1];
      final best = _weekdayKeys[ranked.last.$1 - 1];
      insights.add(
        Insight(
          Icons.event_rounded,
          Pillars.red,
          l.moodInsightHardestDayTitle(l.moodWeekdays(hardest)),
          l.moodInsightHardestDayDetail(
            l.moodWeekdays(best),
            l.moodWeekdaysMidSentence(hardest),
          ),
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
        Insight(
          Icons.trending_up_rounded,
          Pillars.blue,
          l.moodInsightBetterTitle,
          l.moodInsightBetterDetail,
        ),
      );
    } else if (diff <= -0.4) {
      insights.add(
        Insight(
          Icons.trending_down_rounded,
          Pillars.red,
          l.moodInsightHarderTitle,
          l.moodInsightHarderDetail,
        ),
      );
    }
  }

  // What the post-session answers say.
  final line = FeelingStore.summarise(feelings).lineFor(l);
  if (line != null) {
    insights.add(
      Insight(
        Icons.favorite_rounded,
        Pillars.red,
        line,
        l.moodInsightFeelingsDetail,
      ),
    );
  }

  return insights;
}
