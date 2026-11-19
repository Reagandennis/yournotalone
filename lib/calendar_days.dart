/// Day arithmetic on calendar dates rather than on hours.
///
/// Subtracting two local midnights and taking `inDays` counts 24-hour
/// blocks, and the day the clocks go forward is only 23 hours long: across
/// it, "today" minus "yesterday" comes out as zero days, so a streak loses
/// a day and yesterday is labelled today. Adding `Duration(days: n)` goes
/// wrong the other way, landing at 23:00 the day before once the clocks
/// have gone back. These work on the year, month and day alone.
library;

/// How many calendar days [to] is after [from], whatever the time of day
/// on either: 1 from any time on Monday to any time on Tuesday, negative
/// when [to] is the earlier day.
int calendarDaysBetween(DateTime from, DateTime to) {
  // UTC has no daylight saving, so its days are all 24 hours.
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

/// The calendar date [days] days after [day] (before, when negative), at
/// midnight, in the same zone as [day].
DateTime addCalendarDays(DateTime day, int days) => day.isUtc
    ? DateTime.utc(day.year, day.month, day.day + days)
    : DateTime(day.year, day.month, day.day + days);
