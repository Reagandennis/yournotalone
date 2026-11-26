import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/recovery/recovery_repository.dart';

/// The row on the server, updated only as resetDayOne's guard allows.
class _Row {
  _Row(this.day, this.best);

  String day;
  int best;
  final writes = <Map<String, Object>>[];

  Future<bool> update(SeenHabitRow seen, Map<String, Object> values) async {
    if (seen.day != day || best > (values['best_streak_days'] as int)) {
      return false;
    }
    writes.add(values);
    day = values['day_one'] as String;
    best = values['best_streak_days'] as int;
    return true;
  }

  Future<SeenHabitRow?> reload() async => (day: day, best: best);
}

RecoveryHabit _habit(String dayOne, int best) => RecoveryHabit(
  id: 'h1',
  name: 'Drinking',
  dayOne: DateTime.parse(dayOne),
  bestStreakDays: best,
  pledgedToday: false,
);

void main() {
  final today = DateTime(2026, 11, 26, 9);

  Future<void> reset(_Row row, RecoveryHabit habit) => withClock(
    Clock.fixed(today),
    () => resetDayOneGuarded(
      habit,
      today: '2026-11-26',
      update: row.update,
      reload: row.reload,
    ),
  );

  test('an up-to-date copy keeps the streak that ended as the best', () async {
    final row = _Row('2026-11-01', 10);
    await reset(row, _habit('2026-11-01', 10));
    expect(row.day, '2026-11-26');
    // 1 Nov to 26 Nov, both days counted.
    expect(row.best, 26);
    expect(row.writes, hasLength(1));
  });

  test('a stale day one does not count a streak that already ended', () async {
    // Another phone reset the count on the 20th; this one still shows the 1st.
    final row = _Row('2026-11-20', 19);
    await reset(row, _habit('2026-11-01', 5));
    expect(row.day, '2026-11-26');
    // Worked out from the fresh row: max(19, 7), not 26.
    expect(row.best, 19);
  });

  test('a better best from another device is never lowered', () async {
    final row = _Row('2026-11-20', 40);
    await reset(row, _habit('2026-11-20', 3));
    expect(row.best, 40);
    expect(row.day, '2026-11-26');
  });

  test('a habit deleted meanwhile is left alone', () async {
    var reloads = 0;
    await withClock(
      Clock.fixed(today),
      () => resetDayOneGuarded(
        _habit('2026-11-01', 1),
        today: '2026-11-26',
        update: (_, _) async => false,
        reload: () async {
          reloads++;
          return null;
        },
      ),
    );
    expect(reloads, 1);
  });

  test('a reset that is refused again is reported, not taken as done',
      () async {
    final row = _Row('2026-11-01', 1);
    await expectLater(
      withClock(
        Clock.fixed(today),
        () => resetDayOneGuarded(
          _habit('2026-10-01', 1),
          today: '2026-11-26',
          // Another device changes the row every time.
          update: (_, _) async => false,
          reload: row.reload,
        ),
      ),
      throwsA(isA<RecoveryResetConflict>()),
    );
  });

  test('a later day one from another device is not moved earlier', () async {
    // Another phone, its date a day ahead, reset the count on the 27th.
    final row = _Row('2026-11-27', 30);
    await reset(row, _habit('2026-11-01', 5));
    expect(row.day, '2026-11-27');
    expect(row.best, 30);
    expect(row.writes, isEmpty);
  });
}
