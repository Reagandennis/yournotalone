/// Dates and times as the therapy screens show them, in the device's own
/// time zone: "14 Sep 2026", "9:05", "Mon 14 Sep, 9:05" in English, and
/// each language's own order and month names in the others.
library;

import 'package:intl/intl.dart';

import '../l10n/l10n.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The language the app is showing, if it isn't English and its date names
/// are loaded (the localization delegates load them); null otherwise, for
/// the English forms below.
String? _otherLocale() {
  final locale = currentL10n().localeName;
  if (locale == 'en') return null;
  try {
    return DateFormat.localeExists(locale) ? locale : null;
  } catch (_) {
    // No date names loaded at all (a test, or before the app is up).
    return null;
  }
}

String formatDate(DateTime t) {
  final locale = _otherLocale();
  if (locale != null) return DateFormat.yMMMd(locale).format(t);
  return '${t.day} ${_months[t.month - 1]} ${t.year}';
}

String formatTime(DateTime t) {
  final locale = _otherLocale();
  if (locale != null) return DateFormat.Hm(locale).format(t);
  return '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
}

String formatDateTime(DateTime t) {
  final locale = _otherLocale();
  if (locale != null) {
    return '${DateFormat.MMMEd(locale).format(t)}, ${formatTime(t)}';
  }
  return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}, '
      '${formatTime(t)}';
}
