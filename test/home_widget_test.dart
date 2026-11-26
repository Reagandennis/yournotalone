import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/home_widgets/home_widget_sync.dart';
import 'package:yournotalone/l10n/app_localizations_de.dart';
import 'package:yournotalone/l10n/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();
  // A Thursday.
  final now = DateTime(2026, 11, 26, 9, 30);

  HomeWidgetSnapshot snapshot({
    int days = 2,
    int goal = 3,
    String? pickId = 'breathing:Box breathing',
    String? pickTitle = 'Box breathing',
    int? sleepMinutes,
  }) => HomeWidgetSnapshot(
    daysThisWeek: days,
    goal: goal,
    week: const [true, false, true, false, false, false, false],
    todayIndex: 3,
    checkedInToday: false,
    pickId: pickId,
    pickTitle: pickTitle,
    pickMeta: 'Breathing · 4 min',
    sleepMinutes: sleepMinutes,
  );

  test('stores the week, the day it is from and its words', () {
    final data = homeWidgetData(snapshot(), en, now);
    expect(data[HomeWidgetKeys.state], 'ready');
    expect(data[HomeWidgetKeys.day], '2026-11-26');
    expect(data[HomeWidgetKeys.weekStart], '2026-11-23');
    expect(data[HomeWidgetKeys.week], '1010000');
    expect(data[HomeWidgetKeys.days], 2);
    expect(data[HomeWidgetKeys.goal], 3);
    expect(data[HomeWidgetKeys.checkedIn], false);
    expect(data[HomeWidgetKeys.labelDays], '2 of 3 days');
    expect(data[HomeWidgetKeys.labelDaysZero], '0 of 3 days');
    expect(data[HomeWidgetKeys.labelWeek], 'This week');
    expect(data[HomeWidgetKeys.pickId], 'breathing:Box breathing');
    expect(data[HomeWidgetKeys.pickTitle], 'Box breathing');
  });

  test('sleep only when there is some, as a length of time', () {
    expect(
      homeWidgetData(snapshot(), en, now)[HomeWidgetKeys.sleepLine],
      isNull,
    );
    expect(
      homeWidgetData(
        snapshot(sleepMinutes: 0),
        en,
        now,
      )[HomeWidgetKeys.sleepLine],
      isNull,
    );
    expect(
      homeWidgetData(
        snapshot(sleepMinutes: 440),
        en,
        now,
      )[HomeWidgetKeys.sleepLine],
      '7 h 20 min sleep',
    );
  });

  test('a pick without a title or id is left off whole', () {
    final noTitle = homeWidgetData(snapshot(pickTitle: '  '), en, now);
    expect(noTitle[HomeWidgetKeys.pickId], isNull);
    expect(noTitle[HomeWidgetKeys.pickTitle], isNull);
    expect(noTitle[HomeWidgetKeys.pickMeta], isNull);
    final noId = homeWidgetData(snapshot(pickId: null), en, now);
    expect(noId[HomeWidgetKeys.pickTitle], isNull);
  });

  test('a goal out of range is shown within 1–7', () {
    final data = homeWidgetData(snapshot(goal: 12), en, now);
    expect(data[HomeWidgetKeys.goal], 7);
    expect(data[HomeWidgetKeys.labelDays], '2 of 7 days');
  });

  test(
    'a Monday is its own week start, and Sunday belongs to the week before',
    () {
      expect(
        homeWidgetData(
          snapshot(),
          en,
          DateTime(2026, 11, 23),
        )[HomeWidgetKeys.weekStart],
        '2026-11-23',
      );
      expect(
        homeWidgetData(
          snapshot(),
          en,
          DateTime(2026, 11, 29, 23),
        )[HomeWidgetKeys.weekStart],
        '2026-11-23',
      );
    },
  );

  test('words come in the app language', () {
    final data = homeWidgetData(snapshot(), AppLocalizationsDe(), now);
    expect(data[HomeWidgetKeys.labelWeek], 'Diese Woche');
    expect(data[HomeWidgetKeys.labelDays], '2 von 3 Tagen');
  });

  test('everything personal is in the list wiped on sign-out', () {
    final data = homeWidgetData(snapshot(sleepMinutes: 400), en, now);
    final kept = data.keys.toSet()
      ..removeAll(HomeWidgetKeys.personal)
      ..removeAll(HomeWidgetKeys.labels)
      ..remove(HomeWidgetKeys.state);
    expect(kept, isEmpty);
  });
}
