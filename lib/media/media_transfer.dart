import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';

/// Moves one file from a link onto the phone. Behind an interface so the
/// download queue can be tested without the platform downloader.
abstract class MediaTransfer {
  /// Downloads [url] into [file]. Returns whether the whole file arrived;
  /// never throws. [id] names the transfer so it can be cancelled.
  Future<bool> fetch({
    required String id,
    required Uri url,
    required File file,
    required bool wifiOnly,
    void Function(double progress)? onProgress,
  });

  Future<void> cancel(String id);
}

/// [MediaTransfer] on `background_downloader`: the system carries on with
/// a download while the app is in the background, and on iOS even after
/// it's suspended.
class BackgroundTransfer implements MediaTransfer {
  const BackgroundTransfer();

  @override
  Future<bool> fetch({
    required String id,
    required Uri url,
    required File file,
    required bool wifiOnly,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final (baseDirectory, directory, filename) = await Task.split(
        filePath: file.path,
      );
      final task = DownloadTask(
        taskId: id,
        url: url.toString(),
        baseDirectory: baseDirectory,
        directory: directory,
        filename: filename,
        updates: Updates.statusAndProgress,
        requiresWiFi: wifiOnly,
        retries: 2,
      );
      final result = await FileDownloader().download(
        task,
        onProgress: (p) {
          if (p >= 0 && p <= 1) onProgress?.call(p);
        },
      );
      return result.status == TaskStatus.complete;
    } catch (e) {
      debugPrint('Download $id failed: $e');
      return false;
    }
  }

  @override
  Future<void> cancel(String id) async {
    try {
      await FileDownloader().cancelTaskWithId(id);
    } catch (e) {
      debugPrint('Couldn\'t cancel download $id: $e');
    }
  }
}
