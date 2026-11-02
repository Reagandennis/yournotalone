import 'package:flutter/material.dart';

import '../brand.dart';
import '../content/content_catalog.dart';
import '../courses/course_catalog.dart';
import '../home/home_ui.dart';
import 'download_store.dart';
import 'download_strings.dart';

/// The item the published file at [path] belongs to, when this build has
/// to fetch that file; null when it ships in the app or isn't published.
String? downloadableItemAt(String? path) {
  if (path == null) return null;
  final entry = ContentCatalog.instance.mediaAt(path);
  if (entry == null || !entry.remote) return null;
  return entry.itemId;
}

/// Download, progress, or "downloaded" for one item. Shows nothing for an
/// item with nothing to download, so screens can always include it.
class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key, required this.itemId, required this.accent});

  final String? itemId;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final id = itemId;
    final store = DownloadStore.instance;
    if (id == null || !store.canDownload(id)) return const SizedBox.shrink();
    final c = context.brand;
    return AnimatedBuilder(
      animation: Listenable.merge([store, store.waiting]),
      builder: (context, _) {
        final state = store.stateOf(id);
        final (
          Widget icon,
          String tip,
          VoidCallback onTap,
        ) = switch (state.status) {
          DownloadStatus.none => (
            Icon(Icons.download_rounded, color: c.textMuted),
            DownloadStrings.download,
            () => store.download(id),
          ),
          DownloadStatus.queued => (
            Icon(Icons.schedule_rounded, color: c.textMuted),
            store.waiting.value
                ? DownloadStrings.waiting
                : DownloadStrings.queued,
            () => store.remove(id),
          ),
          DownloadStatus.downloading => (
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                strokeWidth: 2.4,
                color: c.accent(accent),
                backgroundColor: c.tint(accent, 0.14),
              ),
            ),
            DownloadStrings.downloading(state.progress),
            () => store.remove(id),
          ),
          DownloadStatus.done => (
            Icon(Icons.download_done_rounded, color: c.accent(accent)),
            DownloadStrings.downloaded,
            () => _confirmRemove(context, id),
          ),
          DownloadStatus.failed => (
            Icon(Icons.error_outline_rounded, color: c.textMuted),
            DownloadStrings.failed,
            () => store.download(id),
          ),
        };
        // The size of the back chip, so a title between them stays centred.
        return IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: icon,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
        );
      },
    );
  }

  Future<void> _confirmRemove(BuildContext context, String id) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline_rounded),
          title: const Text(DownloadStrings.remove),
          onTap: () => Navigator.of(sheetContext).pop(true),
        ),
      ),
    );
    if (remove == true) await DownloadStore.instance.remove(id);
  }
}

/// "Download course": queues every day of [course] that has audio to
/// fetch and that this account can open. Shows nothing if there's none.
class CourseDownloadButton extends StatelessWidget {
  const CourseDownloadButton({super.key, required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final store = DownloadStore.instance;
    final ids = [
      for (final day in course.days)
        if (store.canDownload(day.itemId) &&
            (!day.item.premium || isPremiumUser()))
          day.itemId,
    ];
    if (ids.isEmpty) return const SizedBox.shrink();
    final c = context.brand;
    return AnimatedBuilder(
      animation: Listenable.merge([store, store.waiting]),
      builder: (context, _) {
        final states = [for (final id in ids) store.stateOf(id)];
        final done = states
            .where((s) => s.status == DownloadStatus.done)
            .length;
        final active = states.any((s) => s.active);
        final label = done == ids.length
            ? DownloadStrings.courseDownloaded
            : active && store.waiting.value
            ? DownloadStrings.courseWaiting
            : active
            ? DownloadStrings.courseDownloading(done, ids.length)
            : DownloadStrings.downloadCourse;
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: done == ids.length || active
                ? null
                : () => store.downloadAll(ids),
            icon: Icon(
              done == ids.length
                  ? Icons.download_done_rounded
                  : Icons.download_rounded,
              size: 18,
            ),
            label: Text(label),
            style: TextButton.styleFrom(
              foregroundColor: c.accent(course.accent),
              disabledForegroundColor: c.textMuted,
            ),
          ),
        );
      },
    );
  }
}
