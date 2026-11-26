import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/health/health_data.dart';
import 'package:yournotalone/practice/practice_repository.dart';

void main() {
  final now = DateTime(2026, 11, 25, 8, 30);
  DateTime day(int back) => DateTime(now.year, now.month, now.day - back);
  String key(int back) => PracticeRepository.dateKey(day(back));

  /// Two weeks of 7½-hour nights from 23:00, 8,000 steps, HRV 50, RHR 60,
  /// then [today] and [yesterday] on top.
  HealthHistory history({DailyHealth? today, DailyHealth? yesterday}) {
    final days = <String, DailyHealth>{
      for (var b = 1; b <= 14; b++)
        key(b): DailyHealth(
          day: day(b),
          sleepMinutes: 450,
          bedtime: DateTime(day(b).year, day(b).month, day(b).day - 1, 23),
          steps: 8000,
          hrv: 50,
          restingHeartRate: 60,
        ),
    };
    if (yesterday != null) days[key(1)] = yesterday;
    if (today != null) days[key(0)] = today;
    return HealthHistory(days);
  }

  group('nights', () {
    test('stages either side of midnight make one night, on the day it ends', () {
      final nights = nightsFrom([
        SleepSample(DateTime(2026, 11, 24, 22, 30), DateTime(2026, 11, 24, 23, 45), asleep: true),
        SleepSample(DateTime(2026, 11, 24, 23, 50), DateTime(2026, 11, 25, 3, 0), asleep: true),
        SleepSample(DateTime(2026, 11, 25, 3, 30), DateTime(2026, 11, 25, 6, 30), asleep: true),
      ]);
      expect(nights.keys, ['2026-11-25']);
      expect(nights['2026-11-25']!.minutes, 75 + 190 + 180);
      expect(nights['2026-11-25']!.bedtime, DateTime(2026, 11, 24, 22, 30));
    });

    test('a watch and a phone recording the same night count it once', () {
      final nights = nightsFrom([
        SleepSample(DateTime(2026, 11, 24, 23), DateTime(2026, 11, 25, 7), asleep: true),
        SleepSample(DateTime(2026, 11, 25, 0), DateTime(2026, 11, 25, 6), asleep: true),
      ]);
      expect(nights['2026-11-25']!.minutes, 480);
    });

    test('naps are left out', () {
      final nights = nightsFrom([
        SleepSample(DateTime(2026, 11, 25, 14), DateTime(2026, 11, 25, 15), asleep: true),
      ]);
      expect(nights, isEmpty);
    });

    test('a night recorded only as a session counts the session', () {
      final nights = nightsFrom([
        SleepSample(DateTime(2026, 11, 24, 23), DateTime(2026, 11, 25, 6, 30),
            asleep: true, session: true),
      ]);
      expect(nights['2026-11-25']!.minutes, 450);
    });

    test('stages win over the session that holds them', () {
      final nights = nightsFrom([
        SleepSample(DateTime(2026, 11, 24, 23), DateTime(2026, 11, 25, 7),
            asleep: true, session: true),
        SleepSample(DateTime(2026, 11, 24, 23, 30), DateTime(2026, 11, 25, 6), asleep: true),
      ]);
      expect(nights['2026-11-25']!.minutes, 390);
    });

    test('bedtimes compare across midnight', () {
      expect(bedtimeMinutes(DateTime(2026, 1, 1, 23, 30)), 330);
      expect(bedtimeMinutes(DateTime(2026, 1, 2, 0, 30)), 390);
    });
  });

  group('signals', () {
    test('an ordinary day has none', () {
      expect(
        healthSignals(
          history(today: DailyHealth(day: day(0), sleepMinutes: 400)),
          now,
        ),
        isEmpty,
      );
    });

    test('short against their own usual, or under six hours', () {
      expect(
        healthSignals(history(today: DailyHealth(day: day(0), sleepMinutes: 360)), now),
        contains(HealthSignal.shortSleep),
      );
      expect(
        healthSignals(
          const HealthHistory({}).withDay(DailyHealth(day: day(0), sleepMinutes: 340)),
          now,
        ),
        contains(HealthSignal.shortSleep),
      );
    });

    test('a good night is noticed', () {
      expect(
        healthSignals(history(today: DailyHealth(day: day(0), sleepMinutes: 470)), now),
        contains(HealthSignal.restedNight),
      );
    });

    test('a late night', () {
      expect(
        healthSignals(
          history(
            today: DailyHealth(
              day: day(0),
              sleepMinutes: 420,
              bedtime: DateTime(2026, 11, 25, 1, 0),
            ),
          ),
          now,
        ),
        contains(HealthSignal.lateNight),
      );
    });

    test('heart readings off their usual', () {
      expect(
        healthSignals(history(today: DailyHealth(day: day(0), hrv: 35)), now),
        contains(HealthSignal.bodyUnderStrain),
      );
      expect(
        healthSignals(history(today: DailyHealth(day: day(0), restingHeartRate: 67)), now),
        contains(HealthSignal.bodyUnderStrain),
      );
      expect(
        healthSignals(history(today: DailyHealth(day: day(0), restingHeartRate: 63)), now),
        isNot(contains(HealthSignal.bodyUnderStrain)),
      );
    });

    test('a quiet or a big yesterday', () {
      expect(
        healthSignals(history(yesterday: DailyHealth(day: day(1), steps: 2500)), now),
        contains(HealthSignal.quietDay),
      );
      expect(
        healthSignals(history(yesterday: DailyHealth(day: day(1), steps: 15000)), now),
        contains(HealthSignal.activeDay),
      );
    });

    test('too little history to call anything "usual"', () {
      final h = HealthHistory({
        key(1): DailyHealth(day: day(1), steps: 8000, restingHeartRate: 50),
        key(0): DailyHealth(day: day(0), restingHeartRate: 80, sleepMinutes: 400),
      });
      expect(healthSignals(h, now), isEmpty);
    });
  });

  group('mood links', () {
    test('shown once both sides have enough days, as their own averages', () {
      final days = <String, DailyHealth>{};
      final moods = <String, int>{};
      for (var b = 0; b < 12; b++) {
        final good = b.isEven;
        days[key(b)] = DailyHealth(day: day(b), sleepMinutes: good ? 480 : 330);
        moods[key(b)] = good ? 4 : 2;
      }
      final links = moodLinks(
        history: HealthHistory(days),
        moods: moods,
        practiceDays: const {},
      );
      final sleep = links.singleWhere((l) => l.kind == MoodLinkKind.sleep);
      expect(sleep.withAverage, 4);
      expect(sleep.withoutAverage, 2);
      expect(sleep.withDays, 6);
    });

    test('not with too few days, or a difference that is noise', () {
      final days = <String, DailyHealth>{
        for (var b = 0; b < 6; b++)
          key(b): DailyHealth(day: day(b), sleepMinutes: b.isEven ? 480 : 330),
      };
      expect(
        moodLinks(
          history: HealthHistory(days),
          moods: {for (var b = 0; b < 6; b++) key(b): b.isEven ? 5 : 1},
          practiceDays: const {},
        ),
        isEmpty,
      );
      final more = <String, DailyHealth>{
        for (var b = 0; b < 12; b++)
          key(b): DailyHealth(day: day(b), sleepMinutes: b.isEven ? 480 : 330),
      };
      expect(
        moodLinks(
          history: HealthHistory(more),
          moods: {for (var b = 0; b < 12; b++) key(b): 3},
          practiceDays: const {},
        ),
        isEmpty,
      );
    });
  });
}

extension on HealthHistory {
  HealthHistory withDay(DailyHealth d) => HealthHistory({...days, d.key: d});
}
