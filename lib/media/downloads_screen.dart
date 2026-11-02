import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import 'download_store.dart';
import 'download_strings.dart';

/// Settings → Downloads & storage: what's saved for offline, how much room
/// it takes, a delete for each and for all, and the Wi-Fi-only switch.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const DownloadsScreen());

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _store = DownloadStore.instance;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  Future<void> _deleteAll() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(DownloadStrings.deleteAllTitle),
        content: Text(DownloadStrings.deleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(DownloadStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(DownloadStrings.delete),
          ),
        ],
      ),
    );
    if (sure == true) await _store.removeAll();
  }

  Widget _wifiRow() {
    final c = context.brand;
    return ValueListenableBuilder<bool>(
      valueListenable: _store.wifiOnly,
      builder: (context, on, _) => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border, width: 1.2),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi_rounded, size: 21, color: c.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DownloadStrings.wifiOnly,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    DownloadStrings.wifiOnlyDetail,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: on, onChanged: _store.setWifiOnly),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 4, top: 22),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: context.brand.textMuted,
      ),
    ),
  );

  Widget _itemRow(String id, DownloadState state) {
    final c = context.brand;
    final status = switch (state.status) {
      DownloadStatus.done => formatBytes(state.bytes),
      DownloadStatus.downloading => DownloadStrings.downloading(state.progress),
      DownloadStatus.queued =>
        _store.waiting.value ? DownloadStrings.waiting : DownloadStrings.queued,
      DownloadStatus.failed => DownloadStrings.failed,
      DownloadStatus.none => '',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            state.status == DownloadStatus.done
                ? Icons.download_done_rounded
                : Icons.downloading_rounded,
            size: 21,
            color: c.textMuted,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, color: c.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
              ],
            ),
          ),
          if (state.status == DownloadStatus.failed)
            IconButton(
              tooltip: DownloadStrings.failed,
              onPressed: () => _store.download(id),
              icon: Icon(Icons.refresh_rounded, color: c.textMuted),
            ),
          IconButton(
            tooltip: DownloadStrings.deleteOne(state.title),
            onPressed: () => _store.remove(id),
            icon: Icon(Icons.delete_outline_rounded, color: c.textMuted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AnimatedBuilder(
              animation: Listenable.merge([_store, _store.waiting]),
              builder: (context, _) {
                final all = _store.value.entries;
                final done = [
                  for (final e in all)
                    if (e.value.status == DownloadStatus.done) e,
                ];
                final pending = [
                  for (final e in all)
                    if (e.value.status != DownloadStatus.done) e,
                ];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: BackChip(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      DownloadStrings.title,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const PillarStripe(),
                    const SizedBox(height: 16),
                    Text(
                      DownloadStrings.intro,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.textMuted,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _wifiRow(),
                    if (pending.isNotEmpty) ...[
                      _sectionLabel(DownloadStrings.inProgress),
                      for (final e in pending) _itemRow(e.key, e.value),
                    ],
                    _sectionLabel(DownloadStrings.onPhone),
                    if (done.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          DownloadStrings.empty,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: c.textMuted,
                            height: 1.5,
                          ),
                        ),
                      )
                    else ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          DownloadStrings.using(formatBytes(_store.totalBytes)),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.ink,
                          ),
                        ),
                      ),
                      for (final e in done) _itemRow(e.key, e.value),
                    ],
                    if (done.isNotEmpty || pending.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _deleteAll,
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: Text(DownloadStrings.deleteAll),
                          style: TextButton.styleFrom(
                            foregroundColor: Pillars.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
