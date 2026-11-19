import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../content/content_catalog.dart';
import '../home/home_ui.dart';
import 'media_files.dart';
import 'media_links.dart';
import 'media_transfer.dart';

enum DownloadStatus { none, queued, downloading, done, failed }

/// Where one item's download is.
@immutable
class DownloadState {
  const DownloadState(
    this.status, {
    this.progress = 0,
    this.bytes = 0,
    this.title = '',
  });

  static const none = DownloadState(DownloadStatus.none);

  final DownloadStatus status;

  /// 0–1 while downloading.
  final double progress;

  /// The item's size on the phone once done; its size to fetch before.
  final int bytes;
  final String title;

  bool get active =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;
}

/// Whether a download may start on [network]: never offline, and only on
/// Wi-Fi (or a cable) when [wifiOnly] is on.
bool mayDownload({
  required bool wifiOnly,
  required List<ConnectivityResult> network,
}) {
  final online = network.any((n) => n != ConnectivityResult.none);
  if (!online) return false;
  if (!wifiOnly) return true;
  return network.any(
    (n) => n == ConnectivityResult.wifi || n == ConnectivityResult.ethernet,
  );
}

/// The phone's connection. Behind an interface for tests.
abstract class NetworkStatus {
  Future<List<ConnectivityResult>> current();
  Stream<List<ConnectivityResult>> get changes;
}

class ConnectivityNetwork implements NetworkStatus {
  const ConnectivityNetwork();

  @override
  Future<List<ConnectivityResult>> current() =>
      Connectivity().checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get changes =>
      Connectivity().onConnectivityChanged;
}

/// Audio saved for offline use, by item id. A [ValueNotifier] so every
/// download button and the storage screen stay in step.
///
/// Downloads run one at a time from a queue that survives the app closing.
/// Each file is checked against its sha256 before it's kept. Wi-Fi only by
/// default; with no Wi-Fi the queue waits and carries on when it's back.
class DownloadStore extends ValueNotifier<Map<String, DownloadState>> {
  DownloadStore._({
    MediaTransfer? transfer,
    MediaLinks? links,
    MediaFiles? files,
    NetworkStatus? network,
    List<MediaEntry> Function(String itemId)? entriesFor,
    bool Function()? isPremium,
  }) : _transfer = transfer ?? const BackgroundTransfer(),
       _links = links ?? MediaLinks.instance,
       _files = files ?? MediaFiles.instance,
       _network = network ?? const ConnectivityNetwork(),
       _entriesFor = entriesFor ?? ContentCatalog.instance.downloadableFor,
       _isPremium = isPremium ?? _premiumNow,
       super(const {});

  /// Replaceable so widget tests can use a store on fakes.
  static DownloadStore instance = DownloadStore._();

  @visibleForTesting
  factory DownloadStore.forTest({
    required MediaTransfer transfer,
    required MediaLinks links,
    required MediaFiles files,
    required NetworkStatus network,
    required List<MediaEntry> Function(String itemId) entriesFor,
    bool Function()? isPremium,
  }) => DownloadStore._(
    transfer: transfer,
    links: links,
    files: files,
    network: network,
    entriesFor: entriesFor,
    isPremium: isPremium,
  );

  static bool _premiumNow() {
    try {
      return isPremiumUser();
    } catch (_) {
      return false; // Billing or Supabase not set up (tests, a failed start).
    }
  }

  /// Finished downloads: id → title, bytes and the files' sha256s.
  static const _doneKey = 'media.downloads';

  /// Item ids waiting to download, in order.
  static const _queueKey = 'media.downloads.queue';
  static const _wifiOnlyKey = 'media.downloads.wifiOnly';

  final MediaTransfer _transfer;
  final MediaLinks _links;
  final MediaFiles _files;
  final NetworkStatus _network;
  final List<MediaEntry> Function(String itemId) _entriesFor;
  final bool Function() _isPremium;

  /// Downloads wait for Wi-Fi unless this is off. On by default.
  final wifiOnly = ValueNotifier<bool>(true);

  /// True while queued downloads are held back by [wifiOnly] or being
  /// offline.
  final waiting = ValueNotifier<bool>(false);

  final _queue = <String>[];
  Map<String, Map<String, dynamic>> _done = {};

  /// Items whose last attempt failed, until they're tried again.
  final _failed = <String>{};

  /// The item downloading now, and how far it's got.
  String? _current;
  double _currentProgress = 0;

  /// Files being fetched, by sha256.
  final _inFlight = <String, _Fetch>{};
  Future<void>? _loading;
  Future<void>? _running;
  StreamSubscription<List<ConnectivityResult>>? _networkSub;

  /// Reads what's downloaded and carries on with the queue. Downloads
  /// whose files have gone (the user cleared the app's data, say) are
  /// forgotten, and so are ones the catalogue has since given new audio
  /// (see below). A call while it's reading waits for it, so nothing
  /// starts a download before it has finished.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      wifiOnly.value = prefs.getBool(_wifiOnlyKey) ?? true;
      _done = _decode(prefs.getString(_doneKey));
      _queue
        ..clear()
        ..addAll(prefs.getStringList(_queueKey) ?? const []);
      final outOfDate = <String>[];
      for (final MapEntry(key: id, value: saved) in {..._done}.entries) {
        // A catalogue update re-recorded or re-encoded the item: its audio
        // has a new sha256, and the player looks files up by that, so this
        // copy can never play again. (No entries at all says nothing: the
        // catalogue may not have loaded, so the download is left alone.)
        final now = _entriesFor(id);
        if (now.isNotEmpty &&
            !setEquals(_filesOf(saved), {for (final e in now) e.ref.sha256})) {
          _done.remove(id);
          outOfDate.add(id);
          continue;
        }
        for (final sha in _filesOf(saved)) {
          if (!await (await _files.downloadFor(sha)).exists()) {
            _done.remove(id);
            break;
          }
        }
      }
      // They were downloaded to be there offline, so fetch the new audio
      // the way a tap would: it waits for Wi-Fi like any download (with
      // Wi-Fi only on), and premium audio is only fetched for someone who
      // can still open it. An item that isn't fetched again shows as not
      // downloaded.
      for (final id in outOfDate) {
        if (!_queue.contains(id) && _mayFetch(id)) _queue.add(id);
      }
      // The old files go, with anything else nothing uses, so the storage
      // total is what's on the phone.
      await _deleteUnused();
      _publish();
      await _persist();
    } catch (e) {
      debugPrint('Downloads unavailable: $e');
    }
    _networkSub ??= _network.changes.listen((_) {
      if (_queue.isNotEmpty) unawaited(_pump());
    }, onError: (Object e) => debugPrint('Connection changes unavailable: $e'));
    unawaited(_pump());
  }

  DownloadState stateOf(String itemId) => value[itemId] ?? DownloadState.none;

  /// Whether [itemId] has audio to download in this build.
  bool canDownload(String itemId) => _entriesFor(itemId).isNotEmpty;

  /// Queues [itemId]. Does nothing if it's done, queued, or has nothing
  /// to download.
  Future<void> download(String itemId) => downloadAll([itemId]);

  /// Queues every one of [itemIds] that has audio to download — "Download
  /// course".
  Future<void> downloadAll(Iterable<String> itemIds) async {
    await load();
    var added = false;
    for (final id in itemIds) {
      if (!canDownload(id) || _queue.contains(id) || _done.containsKey(id)) {
        continue;
      }
      _queue.add(id);
      added = true;
    }
    if (!added) return;
    _publish();
    await _persist();
    unawaited(_pump());
  }

  /// Deletes [itemId]'s download, or stops it if it's still coming.
  Future<void> remove(String itemId) async {
    final queued = _queue.remove(itemId);
    final saved = _done.remove(itemId);
    _failed.remove(itemId);
    final shas = <String>{
      ..._filesOf(saved),
      for (final e in _entriesFor(itemId)) e.ref.sha256,
    };
    if (queued) {
      for (final sha in shas) {
        await _cancel(sha);
      }
    }
    // A file another download still uses stays.
    final kept = {for (final s in _done.values) ..._filesOf(s)};
    for (final sha in shas.difference(kept)) {
      await _deleteFiles(sha);
    }
    _publish();
    await _persist();
  }

  /// Deletes every download and empties the queue.
  Future<void> removeAll() async {
    final ids = {..._queue, ..._done.keys};
    _queue.clear();
    _done.clear();
    _failed.clear();
    for (final id in ids) {
      for (final e in _entriesFor(id)) {
        await _cancel(e.ref.sha256);
      }
    }
    try {
      final dir = await _files.downloadsDir;
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('Couldn\'t clear downloads: $e');
    }
    _publish();
    await _persist();
  }

  Future<void> setWifiOnly(bool on) async {
    wifiOnly.value = on;
    if (!on) {
      // A download already started under Wi-Fi only is held back by the
      // system, not by the queue, which is waiting on it; telling the
      // queue does nothing. Start it again without the hold.
      for (final fetch in [..._inFlight.values]) {
        if (fetch.wifiOnly) _takeOver(fetch);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_wifiOnlyKey, on);
    } catch (e) {
      debugPrint('Couldn\'t save the Wi-Fi setting: $e');
    }
    unawaited(_pump());
  }

  /// Bytes all finished downloads take up. [load] and [_markIfComplete]
  /// delete the files no download uses, so apart from downloads still
  /// under way this is everything in the downloads folder.
  int get totalBytes => [
    for (final s in _done.values) s['bytes'] as int,
  ].fold(0, (a, b) => a + b);

  /// Finished downloads, newest last.
  List<(String, DownloadState)> get downloaded => [
    for (final id in _done.keys) (id, stateOf(id)),
  ];

  /// [entry]'s whole file, fetched now on any connection: a loop needs all
  /// of it before it can play gaplessly. The copy is kept, so the item
  /// shows as downloaded. It never waits for Wi-Fi, even when the queue
  /// is already fetching the same file under Wi-Fi only. Throws
  /// [PremiumRequired] or [MediaUnavailable].
  Future<File> fetchNow(MediaEntry entry) async {
    await load();
    final file = await _fetchFile(entry, wifiOnly: false);
    if (file == null) throw const MediaUnavailable('download failed');
    await _markIfComplete(entry.itemId);
    return file;
  }

  /// Runs the queue until it's empty or has to wait for a connection. A
  /// call while it's running is a no-op; it picks up new items itself.
  Future<void> _pump() {
    if (_running case final running?) return running;
    return _running = _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      List<ConnectivityResult> network;
      try {
        network = await _network.current();
      } catch (_) {
        network = const [ConnectivityResult.none];
      }
      if (!mayDownload(wifiOnly: wifiOnly.value, network: network)) {
        waiting.value = true;
        return;
      }
      waiting.value = false;
      final id = _queue.first;
      final ok = await _downloadItem(id);
      // Removed while it was downloading: nothing more to do.
      if (!_queue.contains(id)) continue;
      _queue.remove(id);
      if (!ok) _failed.add(id);
      _publish();
      await _persist();
    }
    waiting.value = false;
  }

  Future<bool> _downloadItem(String id) async {
    _failed.remove(id);
    final entries = _entriesFor(id);
    if (entries.isEmpty) return false;
    final total = entries.fold<int>(0, (a, e) => a + e.ref.bytes);
    var before = 0;
    _current = id;
    _currentProgress = 0;
    _publish();
    try {
      for (final e in entries) {
        final file = await _fetchFile(
          e,
          wifiOnly: wifiOnly.value,
          onProgress: (p) {
            _currentProgress = total == 0
                ? 0
                : (before + p * e.ref.bytes) / total;
            _publish();
          },
        );
        if (file == null) return false;
        before += e.ref.bytes;
      }
      return await _markIfComplete(id);
    } catch (e) {
      debugPrint('Download of $id failed: $e');
      return false;
    } finally {
      _current = null;
    }
  }

  /// Records [itemId] as downloaded if every file it needs is here.
  Future<bool> _markIfComplete(String itemId) async {
    final entries = _entriesFor(itemId);
    if (entries.isEmpty) return false;
    for (final e in entries) {
      if (await _files.downloaded(e.ref) == null) return false;
    }
    final before = _filesOf(_done[itemId]);
    _done[itemId] = {
      'title': entries.first.title,
      'bytes': entries.fold<int>(0, (a, e) => a + e.ref.bytes),
      'files': [for (final e in entries) e.ref.sha256],
    };
    // Fetched again after a catalogue update gave it new audio: the old
    // files can't play any more, and nothing would count or delete them.
    final used = _inUse();
    for (final sha in before) {
      if (!used.contains(sha)) await _deleteFiles(sha);
    }
    _failed.remove(itemId);
    _publish();
    await _persist();
    return true;
  }

  /// [entry]'s file, downloading and checking it if it isn't here yet.
  /// Null on failure. Asks for the same file share one download, except
  /// that one which may use any connection never waits on one held to
  /// Wi-Fi: that is started again without the hold (see [_takeOver]).
  Future<File?> _fetchFile(
    MediaEntry entry, {
    required bool wifiOnly,
    void Function(double)? onProgress,
  }) async {
    final have = await _files.downloaded(entry.ref);
    if (have != null) return have;
    var fetch = switch (_inFlight[entry.ref.sha256]) {
      null => _begin(entry, wifiOnly: wifiOnly),
      final held when held.wifiOnly && !wifiOnly => _takeOver(held),
      final running => running,
    };
    // Followed through a take-over, so whoever was waiting on a held
    // transfer gets the file the new one brings.
    while (true) {
      if (onProgress != null) fetch.listeners.add(onProgress);
      final File? file;
      try {
        file = await fetch.done;
      } finally {
        if (onProgress != null) fetch.listeners.remove(onProgress);
      }
      final next = fetch.takenOver;
      if (file != null || next == null) return file;
      fetch = next;
    }
  }

  /// Starts fetching [entry]'s file. [now] marks a transfer that took over
  /// from one held to Wi-Fi: it has its own task and file, so the two never
  /// collide, even if the held one can't be stopped in time.
  _Fetch _begin(MediaEntry entry, {required bool wifiOnly, bool now = false}) {
    final sha = entry.ref.sha256;
    final fetch = _Fetch(entry, wifiOnly: wifiOnly, taskId: _taskId(sha, now));
    _inFlight[sha] = fetch;
    unawaited(() async {
      try {
        fetch.finish(
          await _fetchAndCheck(entry, fetch, wifiOnly: wifiOnly, now: now),
        );
      } catch (e, stack) {
        fetch.fail(e, stack);
      } finally {
        if (identical(_inFlight[sha], fetch)) _inFlight.remove(sha);
      }
    }());
    return fetch;
  }

  /// Fetches [held]'s file again on any connection, and lets [held] go: a
  /// transfer the system holds until there's Wi-Fi, which off Wi-Fi never
  /// finishes. Those waiting on [held] move to the new transfer.
  _Fetch _takeOver(_Fetch held) {
    final fetch = _begin(held.entry, wifiOnly: false, now: true);
    held.takenOver = fetch;
    held.finish(null);
    unawaited(_transfer.cancel(held.taskId));
    return fetch;
  }

  Future<File?> _fetchAndCheck(
    MediaEntry entry,
    _Fetch fetch, {
    required bool wifiOnly,
    required bool now,
  }) async {
    final sha = entry.ref.sha256;
    final url = await _links.urlFor(entry, MediaPurpose.download);
    final part = await _files.partFor(sha, now: now);
    await part.parent.create(recursive: true);
    final ok = await _transfer.fetch(
      id: fetch.taskId,
      url: url,
      file: part,
      wifiOnly: wifiOnly,
      onProgress: fetch.report,
    );
    if (!ok || !await part.exists()) return null;
    if (!await verifyFile(part, sha)) return null;
    return part.rename((await _files.downloadFor(sha)).path);
  }

  String _taskId(String sha, [bool now = false]) =>
      now ? 'media-$sha-now' : 'media-$sha';

  /// Stops [sha]'s transfer: the queue's, and one started to play it now.
  Future<void> _cancel(String sha) async {
    await _transfer.cancel(_taskId(sha));
    if (_inFlight[sha] case final fetch? when fetch.taskId != _taskId(sha)) {
      await _transfer.cancel(fetch.taskId);
    }
  }

  /// [saved]'s files' sha256s; none for no record.
  static Set<String> _filesOf(Map<String, dynamic>? saved) => {
    ...?(saved?['files'] as List?)?.cast<String>(),
  };

  /// Whether this account may fetch [itemId]'s audio: premium audio only
  /// with Premium, as the Worker signs links for nobody else.
  bool _mayFetch(String itemId) =>
      !_entriesFor(itemId).any((e) => e.ref.premium) || _isPremium();

  /// The files something still needs: finished downloads, and those
  /// [_coming].
  Set<String> _inUse() => {
    for (final saved in _done.values) ..._filesOf(saved),
    ..._coming(),
  };

  /// The files of the queue's items and of transfers under way.
  Set<String> _coming() => {
    for (final id in _queue)
      for (final e in _entriesFor(id)) e.ref.sha256,
    ..._inFlight.keys,
  };

  /// Deletes every file in the downloads folder that nothing uses: audio a
  /// catalogue update replaced, or half a file from a download given up or
  /// stopped for another to take over. Files with names this store doesn't
  /// give are left alone.
  Future<void> _deleteUnused() async {
    try {
      final dir = await _files.downloadsDir;
      if (!await dir.exists()) return;
      final used = _inUse();
      final coming = _coming();
      await for (final file in dir.list()) {
        if (file is! File) continue;
        final name = file.uri.pathSegments.last;
        final sha = MediaFiles.shaNamed(name);
        if (sha == null) continue;
        // Half a file is only worth keeping while its download may finish.
        final keep = name.endsWith('.part')
            ? coming.contains(sha)
            : used.contains(sha);
        if (!keep) await _delete(file);
      }
    } catch (e) {
      debugPrint('Couldn\'t tidy downloads: $e');
    }
  }

  /// Deletes [sha]'s download and any part of one.
  Future<void> _deleteFiles(String sha) async {
    await _delete(await _files.downloadFor(sha));
    await _delete(await _files.partFor(sha));
    await _delete(await _files.partFor(sha, now: true));
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Couldn\'t delete ${file.path}: $e');
    }
  }

  void _publish() {
    value = {
      for (final MapEntry(key: id, value: saved) in _done.entries)
        id: DownloadState(
          DownloadStatus.done,
          progress: 1,
          bytes: saved['bytes'] as int,
          title: saved['title'] as String,
        ),
      for (final id in _queue)
        if (!_done.containsKey(id))
          id: DownloadState(
            id == _current ? DownloadStatus.downloading : DownloadStatus.queued,
            progress: id == _current ? _currentProgress : 0,
            bytes: _bytesOf(id),
            title: _titleOf(id),
          ),
      for (final id in _failed)
        if (!_done.containsKey(id) && !_queue.contains(id))
          id: DownloadState(
            DownloadStatus.failed,
            bytes: _bytesOf(id),
            title: _titleOf(id),
          ),
    };
  }

  int _bytesOf(String id) =>
      _entriesFor(id).fold<int>(0, (a, e) => a + e.ref.bytes);

  String _titleOf(String id) {
    final entries = _entriesFor(id);
    return entries.isEmpty ? id : entries.first.title;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_doneKey, jsonEncode(_done));
      await prefs.setStringList(_queueKey, [..._queue]);
    } catch (e) {
      debugPrint('Couldn\'t save downloads: $e');
    }
  }

  Map<String, Map<String, dynamic>> _decode(String? raw) {
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map<String, dynamic>).map(
        (id, saved) => MapEntry(id, saved as Map<String, dynamic>),
      );
    } catch (_) {
      return {};
    }
  }

  @override
  void dispose() {
    _networkSub?.cancel();
    wifiOnly.dispose();
    waiting.dispose();
    super.dispose();
  }

  @visibleForTesting
  Future<void> idle() async {
    while (_running != null) {
      await _running;
    }
  }

  @visibleForTesting
  Future<void> reset() async {
    await _networkSub?.cancel();
    _networkSub = null;
    _loading = null;
    _queue.clear();
    _done = {};
    _failed.clear();
    _inFlight.clear();
    wifiOnly.value = true;
    waiting.value = false;
    value = const {};
  }
}

/// One file on its way, which everyone who asks for it meanwhile follows.
class _Fetch {
  _Fetch(this.entry, {required this.wifiOnly, required this.taskId}) {
    // Followers still get any error; this only stops one nobody followed
    // being reported as uncaught.
    _end.future.ignore();
  }

  final MediaEntry entry;

  /// Whether the system holds the transfer until there's Wi-Fi.
  final bool wifiOnly;
  final String taskId;
  final _end = Completer<File?>();

  /// The transfer on any connection that took over from this one, if one
  /// did.
  _Fetch? takenOver;

  /// Progress callbacks of those following.
  final listeners = <void Function(double)>{};

  /// The checked file, or null if it didn't come.
  Future<File?> get done => _end.future;

  void finish(File? file) {
    if (!_end.isCompleted) _end.complete(file);
  }

  void fail(Object error, StackTrace stack) {
    if (!_end.isCompleted) _end.completeError(error, stack);
  }

  void report(double progress) {
    for (final listener in [...listeners]) {
      listener(progress);
    }
  }
}
