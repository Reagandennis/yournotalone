/// Dates and times as the therapy screens show them, in the device's own
/// time zone: "14 Sep 2026", "9:05", "Mon 14 Sep, 9:05".
library;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatDate(DateTime t) => '${t.day} ${_months[t.month - 1]} ${t.year}';

String formatTime(DateTime t) =>
    '${t.hour}:${t.minute.toString().padLeft(2, '0')}';

String formatDateTime(DateTime t) =>
    '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}, '
    '${formatTime(t)}';
