/// What to put on the phone's notification schedule, worked out fresh each
/// time the app opens. Pure: the clock, the words and everything known
/// about the person come in as arguments, so tests can check the rules.
///
/// Two kinds of notification come out of here:
///
/// - **Reminders** the person turned on (Settings → Reminders), at the time
///   they chose. Scheduled two weeks ahead rather than repeating forever:
///   daily for a week, then every other day, then they pause. Opening the
///   app starts the window again, so reminders only back off for someone
///   who has stopped opening the app.
/// - **Nudges** the app chooses: a few in the first week, then a handful
///   spaced out when someone has been away (3–6, 7, 14 and 30 days), and
///   nothing after that. Never more than one a day, never at night.
library;

import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import 'engagement.dart';

/// One notification to schedule.
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;

  /// Local wall-clock time.
  final DateTime at;
  final String title;
  final String body;
  final String payload;

  @override
  String toString() => 'PlannedNotification($id, $at, $payload)';
}

// ── Nudges ─────────────────────────────────────────────────────────────

/// Marks a notification payload as an engagement nudge:
/// `nudge:<kind>|<target>`.
const nudgePayloadPrefix = 'nudge:';

/// The nudges, by what they say.
enum NudgeKind {
  /// First week: the next step of their course, or one suggestion.
  firstWeek,

  /// A few days away: a check-in still counts.
  gentle,

  /// A week away: their place is kept.
  saved,

  /// Two weeks away: still here.
  stillHere,

  /// A month away: the last one, and it says so.
  last,

  /// Recent check-ins were very low: support, not practice.
  support,
}

/// Nudge ids: 3000 + the day offset.
const nudgeIdBase = 3000;
const nudgeIdEnd = 3100;

/// Where a tapped nudge leads.
sealed class NudgeTarget {
  const NudgeTarget();

  String encode();

  static NudgeTarget decode(String raw) {
    if (raw.startsWith('course:')) return CourseTarget(raw.substring(7));
    if (raw.startsWith('content:')) return ContentTarget(raw.substring(8));
    if (raw == 'support') return const SupportTarget();
    return const HomeTarget();
  }
}

class HomeTarget extends NudgeTarget {
  const HomeTarget();
  @override
  String encode() => 'home';
}

class SupportTarget extends NudgeTarget {
  const SupportTarget();
  @override
  String encode() => 'support';
}

class CourseTarget extends NudgeTarget {
  const CourseTarget(this.courseId);
  final String courseId;
  @override
  String encode() => 'course:$courseId';
}

class ContentTarget extends NudgeTarget {
  const ContentTarget(this.contentId);
  final String contentId;
  @override
  String encode() => 'content:$contentId';
}

String nudgePayload(NudgeKind kind, NudgeTarget target) =>
    '$nudgePayloadPrefix${kind.name}|${target.encode()}';

/// The kind and target of a nudge payload, or null if it isn't one.
(NudgeKind, NudgeTarget)? parseNudgePayload(String payload) {
  if (!payload.startsWith(nudgePayloadPrefix)) return null;
  final rest = payload.substring(nudgePayloadPrefix.length);
  final bar = rest.indexOf('|');
  final kind = NudgeKind.values.asNameMap()[bar < 0 ? rest : rest.substring(0, bar)];
  if (kind == null) return null;
  return (kind, NudgeTarget.decode(bar < 0 ? '' : rest.substring(bar + 1)));
}

/// The next day of a course they're part-way through.
@immutable
class CourseStep {
  const CourseStep({
    required this.courseId,
    required this.courseTitle,
    required this.dayNumber,
  });

  final String courseId;
  final String courseTitle;

  /// 1-based, as shown.
  final int dayNumber;
}

/// Something to suggest: an item from the content index.
@immutable
class Suggestion {
  const Suggestion({required this.id, required this.title, required this.meta});

  final String id;
  final String title;

  /// "Breathing · 3 min".
  final String meta;
}

/// The hour nudges go out: the hour this person usually opens the app,
/// kept between 9:00 and 20:00 so nothing arrives at night or before
/// people are up. [openHours] are recent opens, newest first.
int nudgeHour(List<int> openHours) {
  if (openHours.isEmpty) return 18;
  final clamped = [for (final h in openHours) h.clamp(9, 20)]..sort();
  return clamped[clamped.length ~/ 2];
}

/// What to schedule, from tomorrow on, given what the app knows as it
/// opens. Empty for the holdout group (see [isEngagementHoldout]) and for
/// anyone who turned nudges off.
List<PlannedNotification> planNudges({
  required AppLocalizations l10n,
  required DateTime now,
  required EngagementSnapshot snapshot,
  required bool enabled,
  required bool holdout,
  required int hour,
  required bool hasReminders,
  required bool lowMood,
  required int totalDays,
  CourseStep? course,
  Suggestion? suggestion,
  Suggestion? newSinceLastVisit,
}) {
  if (!enabled || holdout) return const [];

  final offsets = <int, NudgeKind>{};
  if (lowMood) {
    // Two quiet notes pointing to people who can help, and nothing that
    // asks them to practise.
    offsets[2] = NudgeKind.support;
    offsets[7] = NudgeKind.support;
  } else {
    switch (snapshot.stage) {
      case EngagementStage.newcomer || EngagementStage.returning:
        offsets[1] = NudgeKind.firstWeek;
        offsets[2] = NudgeKind.firstWeek;
        offsets[4] = NudgeKind.firstWeek;
      case EngagementStage.forming ||
          EngagementStage.habit ||
          EngagementStage.slipping ||
          EngagementStage.lapsed:
        // About twice their usual gap: someone who comes every day hears
        // after three days, someone who comes weekly not before six.
        final gap = (snapshot.usualGapDays * 2).round().clamp(3, 6);
        offsets[gap] = NudgeKind.gentle;
    }
    offsets[7] = NudgeKind.saved;
    offsets[14] = NudgeKind.stillHere;
    offsets[30] = NudgeKind.last;
  }

  final today = DateTime(now.year, now.month, now.day);
  final out = <PlannedNotification>[];
  for (final MapEntry(key: offset, value: kind) in offsets.entries) {
    // Their own reminders already cover the first week; nudges only start
    // once those have backed off. Support notes always go.
    if (hasReminders && offset < 7 && kind != NudgeKind.support) continue;
    final at = DateTime(today.year, today.month, today.day + offset, hour);
    final (title, body, target) = _nudgeWords(
      l10n,
      kind,
      course: course,
      suggestion: suggestion,
      newSinceLastVisit: newSinceLastVisit,
      totalDays: totalDays,
    );
    out.add(
      PlannedNotification(
        id: nudgeIdBase + offset,
        at: at,
        title: title,
        body: body,
        payload: nudgePayload(kind, target),
      ),
    );
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

(String, String, NudgeTarget) _nudgeWords(
  AppLocalizations l10n,
  NudgeKind kind, {
  required CourseStep? course,
  required Suggestion? suggestion,
  required Suggestion? newSinceLastVisit,
  required int totalDays,
}) {
  switch (kind) {
    case NudgeKind.firstWeek:
      if (course != null) {
        return (
          l10n.nudgeCourseTitle(course.dayNumber, course.courseTitle),
          l10n.nudgeCourseBody,
          CourseTarget(course.courseId),
        );
      }
      if (suggestion != null) {
        return (
          l10n.nudgeSuggestionTitle,
          l10n.nudgeSuggestionBody(suggestion.title, suggestion.meta),
          ContentTarget(suggestion.id),
        );
      }
      return (l10n.nudgeGentleTitle, l10n.nudgeGentleBody, const HomeTarget());
    case NudgeKind.gentle:
      return (l10n.nudgeGentleTitle, l10n.nudgeGentleBody, const HomeTarget());
    case NudgeKind.saved:
      if (course != null) {
        return (
          l10n.nudgeSavedTitle,
          l10n.nudgeSavedCourseBody(course.dayNumber, course.courseTitle),
          CourseTarget(course.courseId),
        );
      }
      if (newSinceLastVisit != null) {
        return (
          l10n.nudgeSavedTitle,
          l10n.nudgeSavedNewBody(newSinceLastVisit.title),
          ContentTarget(newSinceLastVisit.id),
        );
      }
      return (l10n.nudgeSavedTitle, l10n.nudgeSavedBody, const HomeTarget());
    case NudgeKind.stillHere:
      return (
        l10n.nudgeStillHereTitle,
        l10n.nudgeStillHereBody(totalDays),
        const HomeTarget(),
      );
    case NudgeKind.last:
      return (l10n.nudgeLastTitle, l10n.nudgeLastBody, const HomeTarget());
    case NudgeKind.support:
      return (
        l10n.nudgeSupportTitle,
        l10n.nudgeSupportBody,
        const SupportTarget(),
      );
  }
}

// ── Reminders ──────────────────────────────────────────────────────────

/// A reminder the person turned on, as the planner needs it.
@immutable
class ReminderSetting {
  const ReminderSetting({
    required this.kindName,
    required this.kindId,
    required this.hour,
    required this.minute,
    required this.title,
    required this.bodies,
    required this.payload,
    this.firstBody,
  });

  final String kindName;

  /// [ReminderKind.id], 1–4.
  final int kindId;
  final int hour;
  final int minute;
  final String title;

  /// Rotated day by day, so the same words don't arrive every morning.
  final List<String> bodies;

  /// Said the first time only: something about today, like the next day
  /// of their course.
  final String? firstBody;
  final String payload;
}

/// Days ahead a reminder is scheduled for: daily for a week, then every
/// other day, then nothing until the app is opened again.
const reminderOffsets = [0, 1, 2, 3, 4, 5, 6, 8, 10, 12];

/// Reminder ids: 1000 + kind id × 20 + the day offset, so 1020–1092.
int reminderWindowId(int kindId, int offset) => 1000 + kindId * 20 + offset;

List<PlannedNotification> planReminders({
  required DateTime now,
  required List<ReminderSetting> reminders,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  final out = <PlannedNotification>[];
  for (final r in reminders) {
    var first = true;
    for (final offset in reminderOffsets) {
      final at = DateTime(
        today.year,
        today.month,
        today.day + offset,
        r.hour,
        r.minute,
      );
      if (!at.isAfter(now)) continue;
      final body = first && r.firstBody != null
          ? r.firstBody!
          : r.bodies[(day + offset) % r.bodies.length];
      first = false;
      out.add(
        PlannedNotification(
          id: reminderWindowId(r.kindId, offset),
          at: at,
          title: r.title,
          body: body,
          payload: r.payload,
        ),
      );
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}
