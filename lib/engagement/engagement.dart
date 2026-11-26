/// Where someone is in their time with the app, worked out on the phone
/// from the days they showed up (the same days the weekly rhythm counts).
///
/// The point is to help people keep coming back while it helps them, not
/// to keep them on screen: notifications are capped, back off when they're
/// ignored, carry no guilt or loss language, and stop entirely after a
/// month away. Someone whose recent check-ins are very low is offered
/// support instead of more nudges.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../practice/practice_repository.dart';

/// The stages, in the order people usually move through them.
enum EngagementStage {
  /// The first week with an account.
  newcomer,

  /// Weeks two to four: a routine is forming, or not yet.
  forming,

  /// Past the first month, and turning up about as often as they usually do.
  habit,

  /// Away for longer than is usual for them, but under two weeks.
  slipping,

  /// Two weeks or more away.
  lapsed,

  /// Back within the last week after being away two weeks or more.
  returning,
}

/// Days away that count as lapsed.
const lapsedAfterDays = 14;

@immutable
class EngagementSnapshot {
  const EngagementSnapshot({
    required this.stage,
    required this.accountAgeDays,
    required this.daysSinceActive,
    required this.usualGapDays,
    required this.activeDaysLast28,
  });

  final EngagementStage stage;

  /// Whole days since the account was made; 0 on the first day.
  final int accountAgeDays;

  /// 0 when they showed up today; null when they never have.
  final int? daysSinceActive;

  /// The typical number of days between two days they showed up, over the
  /// last two months (1 = every day). 7 when there's too little history to
  /// say.
  final double usualGapDays;

  /// Days shown up in the last four weeks, today included.
  final int activeDaysLast28;

  /// Pure, so the rules can be tested without a phone or a backend.
  ///
  /// [activeDays] are [PracticeRepository.dateKey]s.
  static EngagementSnapshot compute({
    required Set<String> activeDays,
    required DateTime accountCreated,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    // Calendar arithmetic rather than Durations, so a clock change can't
    // land a day on the wrong side of midnight.
    DateTime back(int days) =>
        DateTime(today.year, today.month, today.day - days);
    bool active(int daysBack) =>
        activeDays.contains(PracticeRepository.dateKey(back(daysBack)));

    final created = DateTime(
      accountCreated.year,
      accountCreated.month,
      accountCreated.day,
    );
    var age = 0;
    while (age < 3650 && back(age).isAfter(created)) {
      age++;
    }

    int? since;
    for (var d = 0; d <= 3650; d++) {
      if (active(d)) {
        since = d;
        break;
      }
    }

    // Gaps between consecutive active days over the last 60, newest first.
    final recent = [
      for (var d = 0; d < 60; d++)
        if (active(d)) d,
    ];
    final gaps = [
      for (var i = 1; i < recent.length; i++) (recent[i] - recent[i - 1]),
    ]..sort();
    final usualGap = gaps.length < 3
        ? 7.0
        : gaps.length.isOdd
        ? gaps[gaps.length ~/ 2].toDouble()
        : (gaps[gaps.length ~/ 2 - 1] + gaps[gaps.length ~/ 2]) / 2;

    var last28 = 0;
    for (var d = 0; d < 28; d++) {
      if (active(d)) last28++;
    }

    // Back after a long gap: the first day of the current run came after
    // two weeks or more away, and was within the last week. Only days the
    // account existed count as away.
    var returning = false;
    if (since != null && since < 7) {
      var runStart = since;
      for (var d = since + 1; d <= age; d++) {
        if (active(d)) runStart = d;
        if (d - runStart >= lapsedAfterDays) {
          returning = runStart < 7;
          break;
        }
      }
    }

    final EngagementStage stage;
    if (age < 7) {
      stage = EngagementStage.newcomer;
    } else if (since == null || since >= lapsedAfterDays) {
      stage = EngagementStage.lapsed;
    } else if (returning) {
      stage = EngagementStage.returning;
    } else if (since >= 3 && since > usualGap * 2) {
      stage = EngagementStage.slipping;
    } else if (age < 30) {
      stage = EngagementStage.forming;
    } else {
      stage = EngagementStage.habit;
    }

    return EngagementSnapshot(
      stage: stage,
      accountAgeDays: age,
      daysSinceActive: since,
      usualGapDays: usualGap,
      activeDaysLast28: last28,
    );
  }
}

/// One in ten accounts keeps the app as it was before the engine — plain
/// daily reminders, no nudges, no win-back emails — so its effect can be
/// measured against them rather than guessed.
///
/// The same rule runs in the database (`engagement_holdout()` in migration
/// 0036): the first 8 hex digits of the md5 of the account id, as a number,
/// modulo 100, under 10. Change both or neither.
bool isEngagementHoldout(String userId) => engagementBucket(userId) < 10;

/// 0–99, stable for an account across phones and reinstalls.
int engagementBucket(String userId) {
  final hex = md5.convert(utf8.encode(userId)).toString().substring(0, 8);
  return int.parse(hex, radix: 16) % 100;
}

/// "engine" or "holdout", for metrics.
String engagementCohort(String userId) =>
    isEngagementHoldout(userId) ? 'holdout' : 'engine';
