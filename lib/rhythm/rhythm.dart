// The test hook is a private field set from a named parameter, which Dart
// can't express as an initializing formal.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../practice/practice_repository.dart';

/// Rhythm milestones, in weeks, each with the line that marks it.
const rhythmMilestones = {
  1: 'A first week of looking after yourself.',
  4: 'A month of looking after yourself.',
  12: 'Three months of showing up for yourself.',
  26: 'Half a year of small, steady steps.',
  52: 'A whole year of sunrises.',
};

/// How often someone has shown up for themselves: a weekly goal rather than
/// an unbroken daily chain, so a missed day is a rest day, not a failure.
///
/// "Showing up" is any small step — a mood check-in, a practice session or
/// a journal entry.
@immutable
class Rhythm {
  const Rhythm._({
    required this.days,
    required this.goal,
    required this.week,
    required this.todayIndex,
    required this.weeksInRhythm,
    required this.bestWeeks,
    required this.totalDays,
    required this.pastWeeks,
    required this.daysSinceLast,
  });

  /// Every day shown up on, as [PracticeRepository.dateKey]s.
  final Set<String> days;

  /// Days a week the person aims for, 1–7.
  final int goal;

  /// This week, Monday first: whether each day was shown up on.
  final List<bool> week;

  /// Today's place in [week].
  final int todayIndex;

  /// Weeks in a row the goal was met. The current week only counts once
  /// it's met — until then it's still in progress, not missed.
  final int weeksInRhythm;

  /// The longest such run in the history.
  final int bestWeeks;

  /// Days shown up on, in all.
  final int totalDays;

  /// Days shown up in each of the last twelve full weeks, oldest first.
  final List<int> pastWeeks;

  /// Days since the last time before today, or null if there's no
  /// earlier day.
  final int? daysSinceLast;

  int get daysThisWeek => week.where((d) => d).length;
  bool get goalMet => daysThisWeek >= goal;
  bool get showedUpToday => week[todayIndex];
  bool get isEmpty => totalDays == 0;

  /// How far this week's sun has risen, 0–1.
  double get progress => (daysThisWeek / goal).clamp(0.0, 1.0);

  /// Back after a gap of three days or more, and not yet today.
  bool get welcomeBack =>
      !showedUpToday && daysSinceLast != null && daysSinceLast! >= 3;

  /// The milestone line, in the week it's reached.
  String? get milestone => goalMet ? rhythmMilestones[weeksInRhythm] : null;

  /// The same history with today counted — for the moment a check-in is
  /// made, before anything is fetched again.
  Rhythm withToday({DateTime? now}) => compute(
    {...days, PracticeRepository.dateKey(now ?? DateTime.now())},
    goal: goal,
    now: now,
  );

  Rhythm withGoal(int goal, {DateTime? now}) =>
      compute(days, goal: goal, now: now);

  static const _weeksBack = 60;

  /// Pure, so the maths can be tested without a backend.
  static Rhythm compute(Set<String> days, {required int goal, DateTime? now}) {
    goal = goal.clamp(1, 7);
    now ??= DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIndex = today.weekday - 1;
    // Built from the calendar date rather than subtracting a Duration, so
    // a daylight-saving change can't land it on the wrong day.
    DateTime day(int back) =>
        DateTime(today.year, today.month, today.day - back);
    final monday = day(todayIndex);

    int countWeek(int weeksAgo) {
      var n = 0;
      for (var i = 0; i < 7; i++) {
        final d = DateTime(
          monday.year,
          monday.month,
          monday.day - 7 * weeksAgo + i,
        );
        if (days.contains(PracticeRepository.dateKey(d))) n++;
      }
      return n;
    }

    final week = [
      for (var i = 0; i < 7; i++)
        days.contains(
          PracticeRepository.dateKey(
            DateTime(monday.year, monday.month, monday.day + i),
          ),
        ),
    ];
    final counts = [for (var w = 0; w <= _weeksBack; w++) countWeek(w)];

    // The current week joins the run once it's met; until then the run
    // is counted from last week.
    var current = 0;
    for (var w = counts[0] >= goal ? 0 : 1; w <= _weeksBack; w++) {
      if (counts[w] < goal) break;
      current++;
    }
    var best = 0;
    var run = 0;
    for (var w = _weeksBack; w >= 0; w--) {
      run = counts[w] >= goal ? run + 1 : 0;
      if (run > best) best = run;
    }

    int? sinceLast;
    for (var back = 1; back < 400; back++) {
      if (days.contains(PracticeRepository.dateKey(day(back)))) {
        sinceLast = back;
        break;
      }
    }

    return Rhythm._(
      days: days,
      goal: goal,
      week: week,
      todayIndex: todayIndex,
      weeksInRhythm: current,
      bestWeeks: best < current ? current : best,
      totalDays: days.length,
      pastWeeks: [for (var w = 12; w >= 1; w--) counts[w]],
      daysSinceLast: sinceLast,
    );
  }
}

/// The weekly goal, saved on the person's profile (`user_metadata`, like
/// their goals) so it follows them to a new phone or a reinstall. A copy
/// stays on the device for when the profile can't be read.
abstract final class RhythmGoal {
  static const _key = 'rhythm.weekly_goal';
  static const profileKey = 'rhythm_goal';
  static const fallback = 3;

  /// [user] is only for tests; the app always reads the signed-in user.
  static Future<int> read([User? user]) async {
    int? onDevice;
    try {
      final prefs = await SharedPreferences.getInstance();
      onDevice = prefs.getInt(_key);
    } catch (_) {}
    final account = user ?? _signedIn();
    final onProfile = account?.userMetadata?[profileKey];
    if (onProfile is int) return onProfile.clamp(1, 7);
    // Chosen before the goal moved to the profile: carry it over.
    if (onDevice != null && account != null && user == null) {
      unawaited(_saveToProfile(onDevice));
    }
    return (onDevice ?? fallback).clamp(1, 7);
  }

  static Future<void> save(int goal) async {
    goal = goal.clamp(1, 7);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, goal);
    } catch (_) {}
    await _saveToProfile(goal);
    Sentry.metrics.count('rhythm.goal_set.$goal', 1);
  }

  /// Never throws: offline, the device copy holds it until the next save.
  static Future<void> _saveToProfile(int goal) async {
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {profileKey: goal}),
      );
    } catch (error) {
      debugPrint('Rhythm goal not saved to profile: $error');
    }
  }

  static User? _signedIn() {
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }
}

/// Gathers the days someone showed up from mood check-ins, practice and
/// the journal.
class RhythmRepository {
  RhythmRepository({
    PracticeRepository? practice,
    Future<Iterable<DateTime>> Function()? otherDays,
  }) : _practice = practice ?? PracticeRepository(),
       _otherDays = otherDays;

  final PracticeRepository _practice;

  /// Mood and journal days, injectable so tests don't need a backend.
  final Future<Iterable<DateTime>> Function()? _otherDays;

  /// Far enough back to be the whole history — only dates come back for
  /// mood and journal, so it stays light.
  static const _historyDays = 3650;

  Future<Rhythm> fetch() async {
    final results = await Future.wait([
      _practiceDays(),
      _otherDays != null ? _otherDays() : _moodAndJournalDays(),
      RhythmGoal.read(),
    ]);
    final days = {
      for (final d in [
        ...results[0] as Iterable<DateTime>,
        ...results[1] as Iterable<DateTime>,
      ])
        PracticeRepository.dateKey(d),
    };
    return Rhythm.compute(days, goal: results[2] as int);
  }

  // Each source fails on its own: one table being unreachable shouldn't
  // hide the days the others know about.
  Future<Iterable<DateTime>> _practiceDays() async {
    try {
      final sessions = await _practice.fetchRecent(days: _historyDays);
      return [for (final s in sessions) s.completedAt];
    } catch (error) {
      debugPrint('Rhythm: practice days unavailable: $error');
      return const [];
    }
  }

  Future<Iterable<DateTime>> _moodAndJournalDays() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];
    final since = DateTime.now().subtract(const Duration(days: _historyDays));
    final out = <DateTime>[];
    try {
      final rows = await client
          .from('mood_entries')
          .select('entry_date')
          .eq('user_id', userId)
          .gte('entry_date', PracticeRepository.dateKey(since));
      // A calendar date already in the user's own zone.
      out.addAll([
        for (final r in rows) DateTime.parse(r['entry_date'] as String),
      ]);
    } catch (error) {
      debugPrint('Rhythm: mood days unavailable: $error');
    }
    try {
      final rows = await client
          .from('journal_entries')
          .select('created_at')
          .eq('user_id', userId)
          .gte('created_at', since.toUtc().toIso8601String());
      out.addAll([
        for (final r in rows)
          DateTime.parse(r['created_at'] as String).toLocal(),
      ]);
    } catch (error) {
      debugPrint('Rhythm: journal days unavailable: $error');
    }
    return out;
  }
}
