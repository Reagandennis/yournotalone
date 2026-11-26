/// What the app makes of Apple Health / Health Connect data. Pure, so every
/// rule here is tested without a phone.
///
/// Three rules hold throughout:
///
/// - Everything is compared with the person's **own** usual — the median of
///   their last two weeks — never with a population norm. The app doesn't
///   judge anyone's sleep or heart; it notices when today differs from
///   their normal and offers something that fits.
/// - It **describes, never diagnoses**: "shorter than your usual", not
///   "you're sleep-deprived"; "higher than usual", not "you're stressed".
///   Saying that a body signal means a condition would make the app a
///   medical device, and would be wrong as often as right.
/// - None of it leaves the phone (see `health_service.dart`).
library;

import 'package:flutter/foundation.dart';

import '../practice/practice_repository.dart';

/// One calendar day of health data. Sleep belongs to the day it ended on:
/// Tuesday's [sleepMinutes] is Monday night's sleep.
@immutable
class DailyHealth {
  const DailyHealth({
    required this.day,
    this.sleepMinutes,
    this.bedtime,
    this.steps,
    this.hrv,
    this.restingHeartRate,
  });

  final DateTime day;
  final int? sleepMinutes;

  /// When the night's sleep began.
  final DateTime? bedtime;
  final int? steps;

  /// Heart rate variability in milliseconds: SDNN from Apple Health, RMSSD
  /// from Health Connect. The two aren't comparable, which is fine — each
  /// person is only compared with themselves, on one phone.
  final double? hrv;
  final double? restingHeartRate;

  String get key => PracticeRepository.dateKey(day);

  bool get isEmpty =>
      sleepMinutes == null &&
      steps == null &&
      hrv == null &&
      restingHeartRate == null;
}

/// The days that have data, by [PracticeRepository.dateKey].
@immutable
class HealthHistory {
  const HealthHistory(this.days);

  static const empty = HealthHistory({});

  final Map<String, DailyHealth> days;

  DailyHealth? on(DateTime day) => days[PracticeRepository.dateKey(day)];

  bool get isEmpty => days.values.every((d) => d.isEmpty);

  /// The last [count] days up to and including [now], oldest first, with
  /// an empty day where there's no data.
  List<DailyHealth> lastDays(DateTime now, int count) => [
    for (var back = count - 1; back >= 0; back--)
      on(DateTime(now.year, now.month, now.day - back)) ??
          DailyHealth(day: DateTime(now.year, now.month, now.day - back)),
  ];
}

double? _median(Iterable<num?> values) {
  final list = [
    for (final v in values)
      if (v != null) v.toDouble(),
  ]..sort();
  if (list.length < 4) return null; // too few days to call it "usual"
  final mid = list.length ~/ 2;
  return list.length.isOdd ? list[mid] : (list[mid - 1] + list[mid]) / 2;
}

/// Minutes after the evening's 18:00, so bedtimes either side of midnight
/// compare properly (23:30 → 330, 00:30 → 390).
int bedtimeMinutes(DateTime bedtime) {
  final m = bedtime.hour * 60 + bedtime.minute;
  return m >= 18 * 60 ? m - 18 * 60 : m + 6 * 60;
}

/// Someone's usual, from the 14 days before today.
@immutable
class HealthBaseline {
  const HealthBaseline({
    this.sleepMinutes,
    this.bedtime,
    this.steps,
    this.hrv,
    this.restingHeartRate,
  });

  final double? sleepMinutes;

  /// In [bedtimeMinutes].
  final double? bedtime;
  final double? steps;
  final double? hrv;
  final double? restingHeartRate;

  static HealthBaseline from(HealthHistory history, DateTime now) {
    final before = [
      for (var back = 14; back >= 1; back--)
        history.on(DateTime(now.year, now.month, now.day - back)),
    ].whereType<DailyHealth>().toList();
    return HealthBaseline(
      sleepMinutes: _median(before.map((d) => d.sleepMinutes)),
      bedtime: _median([
        for (final d in before)
          if (d.bedtime != null) bedtimeMinutes(d.bedtime!),
      ]),
      steps: _median(before.map((d) => d.steps)),
      hrv: _median(before.map((d) => d.hrv)),
      restingHeartRate: _median(before.map((d) => d.restingHeartRate)),
    );
  }
}

/// What stands out today against someone's usual. Each one is something
/// the app can respond to with a suggestion, or simply notice.
enum HealthSignal {
  /// Last night was well short of their usual (or under six hours).
  shortSleep,

  /// They went to bed much later than usual.
  lateNight,

  /// A good night: at least their usual, and seven hours or more.
  restedNight,

  /// HRV well under, or resting heart rate well over, their usual: the body
  /// has been working harder than normal. Said as exactly that.
  bodyUnderStrain,

  /// Yesterday was much less active than usual.
  quietDay,

  /// Yesterday was much more active than usual.
  activeDay,
}

/// Today's signals, most useful to act on first.
List<HealthSignal> healthSignals(HealthHistory history, DateTime now) {
  final base = HealthBaseline.from(history, now);
  final today = history.on(now);
  final yesterday = history.on(DateTime(now.year, now.month, now.day - 1));
  final out = <HealthSignal>[];

  final sleep = today?.sleepMinutes;
  if (sleep != null && sleep >= 60) {
    final usual = base.sleepMinutes;
    if (sleep < 360 || (usual != null && sleep < usual - 75)) {
      out.add(HealthSignal.shortSleep);
    } else if (sleep >= 420 && (usual == null || sleep >= usual - 15)) {
      out.add(HealthSignal.restedNight);
    }
  }
  if (today?.bedtime case final bed? when base.bedtime != null) {
    if (bedtimeMinutes(bed) > base.bedtime! + 90) {
      out.add(HealthSignal.lateNight);
    }
  }

  final hrv = today?.hrv ?? yesterday?.hrv;
  final rhr = today?.restingHeartRate ?? yesterday?.restingHeartRate;
  if ((hrv != null && base.hrv != null && hrv < base.hrv! * 0.8) ||
      (rhr != null &&
          base.restingHeartRate != null &&
          rhr > base.restingHeartRate! + 5)) {
    out.add(HealthSignal.bodyUnderStrain);
  }

  final steps = yesterday?.steps;
  if (steps != null && base.steps != null && base.steps! >= 1500) {
    if (steps < base.steps! * 0.5) {
      out.add(HealthSignal.quietDay);
    } else if (steps > base.steps! * 1.5 && steps >= 8000) {
      out.add(HealthSignal.activeDay);
    }
  }
  return out;
}

// ── Mood links ─────────────────────────────────────────────────────────

/// What a person's own data shows about how their days and their moods go
/// together. Shown only once there's enough of it to mean something, and
/// always as "on days when…", never as a cause.
enum MoodLinkKind {
  /// Mood after a night of seven hours or more, against after less.
  sleep,

  /// Mood on days of more steps than their usual, against fewer.
  movement,

  /// Mood on days with a meditation or breathing session, against without.
  practice,
}

@immutable
class MoodLink {
  const MoodLink({
    required this.kind,
    required this.withAverage,
    required this.withoutAverage,
    required this.withDays,
    required this.withoutDays,
  });

  final MoodLinkKind kind;

  /// Average mood score (1–5) on the days with the thing (a good night,
  /// an active day, a practice), and without it.
  final double withAverage;
  final double withoutAverage;
  final int withDays;
  final int withoutDays;

  double get difference => withAverage - withoutAverage;
}

/// Days each side needs before a link is shown.
const moodLinkMinDays = 5;

/// [moods] are scores 1–5 by date key; [practiceDays] the date keys with a
/// meditation or breathing session. Links smaller than a third of a step on
/// the scale are left out: they're noise.
List<MoodLink> moodLinks({
  required HealthHistory history,
  required Map<String, int> moods,
  required Set<String> practiceDays,
}) {
  final steps = _median(history.days.values.map((d) => d.steps));
  final groups = <MoodLinkKind, (List<int>, List<int>)>{
    for (final k in MoodLinkKind.values) k: (<int>[], <int>[]),
  };
  for (final MapEntry(key: day, value: mood) in moods.entries) {
    final h = history.days[day];
    if (h?.sleepMinutes case final s? when s >= 60) {
      (s >= 420 ? groups[MoodLinkKind.sleep]!.$1 : groups[MoodLinkKind.sleep]!.$2)
          .add(mood);
    }
    if (h?.steps case final s? when steps != null) {
      (s > steps
              ? groups[MoodLinkKind.movement]!.$1
              : groups[MoodLinkKind.movement]!.$2)
          .add(mood);
    }
    (practiceDays.contains(day)
            ? groups[MoodLinkKind.practice]!.$1
            : groups[MoodLinkKind.practice]!.$2)
        .add(mood);
  }
  double avg(List<int> xs) => xs.reduce((a, b) => a + b) / xs.length;
  final out = <MoodLink>[];
  for (final MapEntry(key: kind, value: (yes, no)) in groups.entries) {
    if (yes.length < moodLinkMinDays || no.length < moodLinkMinDays) continue;
    final link = MoodLink(
      kind: kind,
      withAverage: avg(yes),
      withoutAverage: avg(no),
      withDays: yes.length,
      withoutDays: no.length,
    );
    if (link.difference.abs() >= 0.33) out.add(link);
  }
  out.sort((a, b) => b.difference.abs().compareTo(a.difference.abs()));
  return out;
}

// ── Reading raw samples ────────────────────────────────────────────────

/// A sleep stage or session sample, as read from the platform.
@immutable
class SleepSample {
  const SleepSample(this.from, this.to, {required this.asleep, this.session = false});

  final DateTime from;
  final DateTime to;

  /// Asleep (any stage) rather than awake or in bed.
  final bool asleep;

  /// A whole Health Connect session, used only for nights without stages.
  final bool session;
}

/// The night a sleep sample belongs to, by the day the night ends on, or
/// null for a nap. A sample that starts between 10:00 and 18:00 is a nap;
/// any other belongs to the night whose morning comes after it, so a stage
/// from 22:00 to 23:30 and one from 05:00 to 07:00 land on the same night.
String? nightKey(DateTime from) {
  if (from.hour >= 10 && from.hour < 18) return null;
  return PracticeRepository.dateKey(from.add(const Duration(hours: 12)));
}

/// Minutes covered by [samples], counting overlaps once: a watch and a
/// phone app both recording the same night mustn't double it.
int _coveredMinutes(List<SleepSample> samples) {
  final sorted = [...samples]..sort((a, b) => a.from.compareTo(b.from));
  var total = Duration.zero;
  DateTime? start;
  DateTime? end;
  for (final s in sorted) {
    if (end == null || s.from.isAfter(end)) {
      if (start != null) total += end!.difference(start);
      start = s.from;
      end = s.to;
    } else if (s.to.isAfter(end)) {
      end = s.to;
    }
  }
  if (start != null) total += end!.difference(start);
  return total.inMinutes;
}

/// Nights from sleep samples, each under the day it ended on (see
/// [nightKey]). Asleep stages are summed where there are any; a night
/// recorded only as a session (many Android trackers) counts the session.
Map<String, ({int minutes, DateTime bedtime})> nightsFrom(
  List<SleepSample> samples,
) {
  final stages = <String, List<SleepSample>>{};
  final sessions = <String, List<SleepSample>>{};
  for (final s in samples) {
    if (!s.to.isAfter(s.from)) continue;
    final key = nightKey(s.from);
    if (key == null) continue;
    if (s.session) {
      sessions.putIfAbsent(key, () => []).add(s);
    } else if (s.asleep) {
      stages.putIfAbsent(key, () => []).add(s);
    }
  }
  final out = <String, ({int minutes, DateTime bedtime})>{};
  for (final key in {...stages.keys, ...sessions.keys}) {
    final list = stages[key] ?? sessions[key]!;
    out[key] = (
      minutes: _coveredMinutes(list),
      bedtime: list.map((s) => s.from).reduce((a, b) => a.isBefore(b) ? a : b),
    );
  }
  return out;
}
