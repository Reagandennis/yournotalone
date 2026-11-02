import '../l10n/l10n.dart';

/// Everything the download buttons and the storage screen say, from the
/// ARB files (`download*` keys) in the app's current language.
abstract final class DownloadStrings {
  static AppLocalizations get _l => currentL10n();

  static String get download => _l.downloadAction;
  static String get downloaded => _l.downloadDone;
  static String get queued => _l.downloadQueued;
  static String get waiting => _l.downloadWaitingWifi;
  static String downloading(double progress) =>
      _l.downloadProgress((progress * 100).round());
  static String get failed => _l.downloadFailed;
  static String get remove => _l.downloadRemove;

  static String get downloadCourse => _l.downloadCourse;
  static String get courseDownloaded => _l.downloadCourseDone;
  static String courseDownloading(int done, int total) =>
      _l.downloadCourseProgress(done, total);
  static String get courseWaiting => _l.downloadCourseWaiting;

  static String get preparing => _l.downloadPreparing;
  static String get needsConnection => _l.downloadNeedsConnection;
  static String get premiumNeeded => _l.downloadPremiumNeeded;
  static String get couldNotPlay => _l.downloadCouldNotPlay;

  static String get settingsRow => _l.downloadsTitle;
  static String get title => _l.downloadsTitle;
  static String get intro => _l.downloadsIntro;
  static String get wifiOnly => _l.downloadsWifiOnly;
  static String get wifiOnlyDetail => _l.downloadsWifiOnlyDetail;
  static String using(String size) => _l.downloadsUsing(size);
  static String get inProgress => _l.downloadsInProgress;
  static String get onPhone => _l.downloadsOnPhone;
  static String get empty => _l.downloadsEmpty;
  static String get deleteAll => _l.downloadsDeleteAll;
  static String get deleteAllTitle => _l.downloadsDeleteAllTitle;
  static String get deleteAllBody => _l.downloadsDeleteAllBody;
  static String get cancel => _l.commonCancel;
  static String get delete => _l.commonDelete;
  static String deleteOne(String title) => _l.downloadsDeleteOne(title);
}

/// A size for people: "820 KB", "2.4 MB".
String formatBytes(int bytes) {
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000 * 1000) return '${(bytes / 1000).round()} KB';
  if (bytes < 1000 * 1000 * 1000) {
    return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1000 * 1000 * 1000)).toStringAsFixed(1)} GB';
}
