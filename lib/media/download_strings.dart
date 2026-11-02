/// Everything the download buttons and the storage screen say, in one
/// place so it can move to the translation files in one go.
abstract final class DownloadStrings {
  static const download = 'Download for offline';
  static const downloaded = 'Downloaded';
  static const queued = 'Waiting to download · tap to cancel';
  static const waiting = 'Waiting for Wi-Fi · tap to cancel';
  static String downloading(double progress) =>
      'Downloading ${(progress * 100).round()}% · tap to cancel';
  static const failed = 'Download failed · tap to try again';
  static const remove = 'Remove download';

  static const downloadCourse = 'Download course';
  static const courseDownloaded = 'Course downloaded';
  static String courseDownloading(int done, int total) =>
      'Downloading · $done of $total ready';
  static const courseWaiting = 'Waiting for Wi-Fi to download';

  static const preparing = 'Getting this sound ready…';
  static const needsConnection =
      'Couldn\'t get that sound. Connect to the internet to play it the '
      'first time.';
  static const premiumNeeded = 'This sound is part of Premium.';
  static const couldNotPlay = 'Couldn\'t play that sound.';

  static const settingsRow = 'Downloads & storage';
  static const title = 'Downloads & storage';
  static const intro =
      'Sounds and meditations you\'ve downloaded play without a '
      'connection. Delete them here to free up space.';
  static const wifiOnly = 'Download on Wi-Fi only';
  static const wifiOnlyDetail =
      'Downloads wait for Wi-Fi, so they don\'t use your mobile data.';
  static String using(String size) => 'Using $size on this phone';
  static const inProgress = 'In progress';
  static const onPhone = 'On this phone';
  static const empty =
      'Nothing downloaded yet. Tap the download button on a sound, '
      'meditation or course to keep it for when you\'re offline.';
  static const deleteAll = 'Delete all downloads';
  static const deleteAllTitle = 'Delete all downloads?';
  static const deleteAllBody =
      'They\'ll be removed from this phone. You can download them again '
      'any time.';
  static const cancel = 'Cancel';
  static const delete = 'Delete';
  static String deleteOne(String title) => 'Delete $title';
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
