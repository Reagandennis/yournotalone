/// The one thing to suggest right now, and why: the same pick on Home's
/// health card, the home-screen widget and the first-week nudges, so the
/// app never says three different things at once.
library;

import 'package:flutter/foundation.dart';

import '../courses/course_catalog.dart';
import '../courses/course_progress.dart';
import '../discover/content_index.dart';
import '../discover/content_tags.dart';
import '../discover/taste_store.dart';
import '../health/health_data.dart';
import '../l10n/l10n.dart';

/// Why [NextStep.item] was picked, which is also the line shown with it.
enum NextStepReason {
  shortSleep,
  lateNight,
  bodyUnderStrain,
  quietDay,
  activeDay,
  restedNight,

  /// Between midnight and five: something quiet for getting back to sleep.
  night,
  course,

  /// Something they felt better after before.
  helpedBefore,
  goals,
  timeOfDay;

  /// The reason in words. Descriptive only (see health_data.dart): what
  /// differs from the person's usual, never what it means.
  String line(AppLocalizations l10n, {Course? course, int? day}) =>
      switch (this) {
        shortSleep => l10n.nextStepShortSleep,
        lateNight => l10n.nextStepLateNight,
        bodyUnderStrain => l10n.nextStepBodyUnderStrain,
        quietDay => l10n.nextStepQuietDay,
        activeDay => l10n.nextStepActiveDay,
        restedNight => l10n.nextStepRestedNight,
        night => l10n.nextStepNight,
        helpedBefore => l10n.nextStepHelpedBefore,
        NextStepReason.course when course != null && day != null =>
          l10n.nextStepCourse(day, course.title),
        NextStepReason.course || goals => l10n.nextStepGoals,
        timeOfDay => l10n.nextStepTimeOfDay,
      };

  bool get fromHealth => index <= restedNight.index;
}

@immutable
class NextStep {
  const NextStep({
    required this.item,
    required this.reason,
    this.course,
    this.courseDay,
  });

  final ContentItem item;
  final NextStepReason reason;
  final Course? course;

  /// 1-based, when [reason] is [NextStepReason.course].
  final int? courseDay;

  String line(AppLocalizations l10n) =>
      reason.line(l10n, course: course, day: courseDay);
}

/// What each health signal calls for at this time of day.
Set<Need> _needsFor(HealthSignal signal, DayPart part) {
  final evening = part == DayPart.evening || part == DayPart.night;
  return switch (signal) {
    HealthSignal.shortSleep ||
    HealthSignal.lateNight => evening ? {Need.sleep} : {Need.focus, Need.stressed},
    HealthSignal.bodyUnderStrain => {Need.stressed, Need.anxious},
    HealthSignal.quietDay => {Need.low},
    HealthSignal.activeDay => evening ? {Need.sleep} : {Need.stressed},
    HealthSignal.restedNight => const {},
  };
}

NextStepReason _reasonFor(HealthSignal signal) => switch (signal) {
  HealthSignal.shortSleep => NextStepReason.shortSleep,
  HealthSignal.lateNight => NextStepReason.lateNight,
  HealthSignal.bodyUnderStrain => NextStepReason.bodyUnderStrain,
  HealthSignal.quietDay => NextStepReason.quietDay,
  HealthSignal.activeDay => NextStepReason.activeDay,
  HealthSignal.restedNight => NextStepReason.restedNight,
};

/// The course day that's open today, if someone is part-way through one.
({Course course, int day, ContentItem item})? openCourseDay(DateTime now) {
  final course = CourseStore.instance.active;
  if (course == null) return null;
  final progress = CourseStore.instance.of(course);
  final next = progress.nextDay(course);
  if (next == null || !progress.isOpen(course, next, now)) return null;
  final id = course.days[next].itemId;
  final item = contentIndex.where((i) => i.id == id).firstOrNull;
  if (item == null) return null;
  return (course: course, day: next + 1, item: item);
}

/// The tool for lying awake, offered first at night to those who can open it.
const awakeToolId = 'tool:Awake at 3am?';

/// What's offered between midnight and five: things to listen to or
/// breathe with, and the tool for lying awake. Nothing to read or write,
/// and nothing that digs into what's hard.
bool fitsTheNight(ContentItem item) =>
    !deepContent.contains(item.id) &&
    (item.id == awakeToolId ||
        item.kind == ContentKind.sound ||
        item.kind == ContentKind.breathing ||
        item.kind == ContentKind.meditation);

/// Picks today's one suggestion. In the middle of the night, something
/// quiet for sleep. Otherwise a night or a body reading that's off the
/// person's usual comes first — that's what the moment needs — then the
/// day of their course, then their goals, then the time of day.
NextStep? chooseNextStep({
  required DateTime now,
  required bool premium,
  List<HealthSignal> signals = const [],
  Set<Need> goals = const {},
  List<ContentItem>? from,
  Taste? taste,
}) {
  final part = DayPart.of(now);
  final liked = taste ?? TasteStore.instance.current;
  ContentItem? best(Set<Need> needs, {List<ContentItem>? pool}) {
    final picks = recommend(
      needs: needs,
      dayPart: part,
      count: 1,
      now: now,
      premium: premium,
      goals: goals,
      from: pool ?? from,
      taste: liked,
    );
    // Free first for the free plan (see recommend); a locked pick would
    // only open the paywall from a widget or a notification.
    final pick = picks.firstOrNull;
    return pick == null || (pick.premium && !premium) ? null : pick;
  }

  if (part == DayPart.night) {
    final pool = (from ?? contentIndex).where(fitsTheNight).toList();
    final awake = pool.where((i) => i.id == awakeToolId).firstOrNull;
    final item = awake != null &&
            (premium || !awake.premium) &&
            !liked.dismissed.contains(awake.id)
        ? awake
        : best(const {Need.sleep}, pool: pool);
    if (item != null) return NextStep(item: item, reason: NextStepReason.night);
  }

  // Their own goals and the time of day are the weakest reasons; when the
  // pick is something that helped them before, that's the better one.
  NextStepReason orHelped(ContentItem item, NextStepReason reason) =>
      liked.helped.contains(item.id) ? NextStepReason.helpedBefore : reason;

  final urgent = signals.where(
    (s) => s == HealthSignal.shortSleep || s == HealthSignal.bodyUnderStrain,
  );
  for (final signal in urgent) {
    final item = best(_needsFor(signal, part));
    if (item != null) return NextStep(item: item, reason: _reasonFor(signal));
  }

  if (openCourseDay(now) case final day?) {
    return NextStep(
      item: day.item,
      reason: NextStepReason.course,
      course: day.course,
      courseDay: day.day,
    );
  }

  for (final signal in signals) {
    final needs = _needsFor(signal, part);
    final item = best(needs.isEmpty ? goals : needs);
    if (item != null) return NextStep(item: item, reason: _reasonFor(signal));
  }

  if (goals.isNotEmpty) {
    final item = best(goals);
    if (item != null) {
      return NextStep(item: item, reason: orHelped(item, NextStepReason.goals));
    }
  }
  final item = best(const {});
  if (item != null) {
    return NextStep(item: item, reason: orHelped(item, NextStepReason.timeOfDay));
  }
  return null;
}
