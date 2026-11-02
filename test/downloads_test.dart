import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/media/download_store.dart';
import 'package:yournotalone/media/download_strings.dart';
import 'package:yournotalone/media/downloads_screen.dart';
import 'package:yournotalone/media/media_files.dart';
import 'package:yournotalone/media/media_links.dart';
import 'package:yournotalone/media/media_transfer.dart';

MediaEntry _entry(String id, List<int> bytes, {String role = 'audio'}) {
  final sha = sha256.convert(bytes).toString();
  return MediaEntry(
    itemId: id,
    title: id.split(':').last,
    role: role,
    path: 'assets/$id.m4a',
    ref: MediaRef(
      key: 'media/$sha.m4a',
      sha256: sha,
      bytes: bytes.length,
      premium: false,
    ),
  );
}

/// Writes whatever the "server" has for a URL. A download can be held
/// part-way with [hold] to look at it mid-flight.
class _Transfer implements MediaTransfer {
  _Transfer(this.server);

  /// Bytes by URL path.
  final Map<String, List<int>> server;
  final fetched = <String>[];
  final wifiOnlyAsked = <bool>[];
  final cancelled = <String>[];
  Completer<void>? hold;

  @override
  Future<bool> fetch({
    required String id,
    required Uri url,
    required File file,
    required bool wifiOnly,
    void Function(double progress)? onProgress,
  }) async {
    fetched.add(url.path);
    wifiOnlyAsked.add(wifiOnly);
    final bytes = server[url.path];
    if (bytes == null) return false;
    onProgress?.call(0.5);
    if (hold case final h?) await h.future;
    if (cancelled.contains(id)) return false;
    await file.writeAsBytes(bytes);
    onProgress?.call(1);
    return true;
  }

  @override
  Future<void> cancel(String id) async => cancelled.add(id);
}

class _Network implements NetworkStatus {
  List<ConnectivityResult> now = [ConnectivityResult.wifi];
  final _changes = StreamController<List<ConnectivityResult>>.broadcast();

  void set(List<ConnectivityResult> network) {
    now = network;
    _changes.add(network);
  }

  @override
  Future<List<ConnectivityResult>> current() async => now;

  @override
  Stream<List<ConnectivityResult>> get changes => _changes.stream;
}

void main() {
  final rainBytes = utf8.encode('rain on a tin roof');
  final scanBytes = utf8.encode('breathe in, breathe out');
  final rain = _entry('sound:Rainfall', rainBytes);
  final scan = _entry('meditation:Body scan', scanBytes, role: 'narration');
  final catalog = {
    rain.itemId: [rain],
    scan.itemId: [scan],
  };

  late Directory root;
  late MediaFiles files;
  late _Transfer transfer;
  late _Network network;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('downloads_test');
    files = MediaFiles(
      support: () async => Directory('${root.path}/support'),
      cache: () async => Directory('${root.path}/cache'),
    );
    transfer = _Transfer({
      '/${rain.ref.key}': rainBytes,
      '/${scan.ref.key}': scanBytes,
    });
    network = _Network();
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// A fresh store, as after the app starts.
  DownloadStore phone() => DownloadStore.forTest(
    transfer: transfer,
    links: MediaLinks(apiUrl: '', baseUrl: 'https://cdn.test/'),
    files: files,
    network: network,
    entriesFor: (id) => catalog[id] ?? const [],
  );

  test('the Wi-Fi rule', () {
    const wifi = [ConnectivityResult.wifi];
    const mobile = [ConnectivityResult.mobile];
    const none = [ConnectivityResult.none];
    expect(mayDownload(wifiOnly: true, network: wifi), isTrue);
    expect(mayDownload(wifiOnly: true, network: mobile), isFalse);
    expect(mayDownload(wifiOnly: false, network: mobile), isTrue);
    expect(mayDownload(wifiOnly: false, network: none), isFalse);
    expect(mayDownload(wifiOnly: true, network: none), isFalse);
    expect(
      mayDownload(wifiOnly: true, network: [ConnectivityResult.ethernet]),
      isTrue,
    );
    expect(
      mayDownload(
        wifiOnly: true,
        network: [ConnectivityResult.wifi, ConnectivityResult.vpn],
      ),
      isTrue,
    );
  });

  test('a download goes queued, downloading, done', () async {
    final store = phone();
    await store.load();
    final seen = <DownloadStatus>[];
    store.addListener(() => seen.add(store.stateOf(rain.itemId).status));
    transfer.hold = Completer();

    await store.download(rain.itemId);
    await pumpEventQueue();
    expect(store.stateOf(rain.itemId).status, DownloadStatus.downloading);
    expect(store.stateOf(rain.itemId).progress, 0.5);

    transfer.hold!.complete();
    await store.idle();
    final state = store.stateOf(rain.itemId);
    expect(state.status, DownloadStatus.done);
    expect(state.bytes, rainBytes.length);
    expect(state.title, 'Rainfall');
    expect(seen.first, DownloadStatus.queued);
    expect(seen, contains(DownloadStatus.downloading));
    final file = File('${root.path}/support/media/${rain.ref.sha256}.m4a');
    expect(file.readAsBytesSync(), rainBytes);
    expect(store.totalBytes, rainBytes.length);
  });

  test('a download that fails its checksum is deleted', () async {
    transfer.server['/${rain.ref.key}'] = utf8.encode('rain on a tin ruff');
    final store = phone();
    await store.load();
    await store.download(rain.itemId);
    await store.idle();
    expect(store.stateOf(rain.itemId).status, DownloadStatus.failed);
    expect(Directory('${root.path}/support/media').listSync(), isEmpty);
    expect(await files.downloaded(rain.ref), isNull);

    // Tapping again tries again.
    transfer.server['/${rain.ref.key}'] = rainBytes;
    await store.download(rain.itemId);
    await store.idle();
    expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
  });

  test('downloads and the queue survive the app restarting', () async {
    final first = phone();
    await first.load();
    await first.download(rain.itemId);
    await first.idle();

    // Queued on mobile data: it waits for Wi-Fi.
    network.set([ConnectivityResult.mobile]);
    await first.download(scan.itemId);
    await first.idle();
    expect(first.stateOf(scan.itemId).status, DownloadStatus.queued);
    expect(first.waiting.value, isTrue);
    first.dispose(); // the app closes

    final second = phone();
    await second.load();
    await second.idle();
    expect(second.stateOf(rain.itemId).status, DownloadStatus.done);
    expect(second.stateOf(scan.itemId).status, DownloadStatus.queued);

    network.set([ConnectivityResult.wifi]);
    await pumpEventQueue();
    await second.idle();
    expect(second.stateOf(scan.itemId).status, DownloadStatus.done);
    expect(second.waiting.value, isFalse);
  });

  test('a download whose file has gone is forgotten', () async {
    final first = phone();
    await first.load();
    await first.download(rain.itemId);
    await first.idle();
    Directory('${root.path}/support').deleteSync(recursive: true);

    final second = phone();
    await second.load();
    expect(second.stateOf(rain.itemId).status, DownloadStatus.none);
  });

  test('with Wi-Fi only off, mobile data is fine', () async {
    network.set([ConnectivityResult.mobile]);
    final store = phone();
    await store.load();
    await store.setWifiOnly(false);
    await store.download(rain.itemId);
    await store.idle();
    expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
    expect(transfer.wifiOnlyAsked, [false]);

    final next = phone();
    await next.load();
    expect(next.wifiOnly.value, isFalse, reason: 'the setting is kept');
  });

  test('Wi-Fi only is the default and is passed to the downloader', () async {
    final store = phone();
    await store.load();
    expect(store.wifiOnly.value, isTrue);
    await store.download(rain.itemId);
    await store.idle();
    expect(transfer.wifiOnlyAsked, [true]);
  });

  test('download course queues only items with audio', () async {
    final store = phone();
    await store.load();
    await store.downloadAll([
      'tool:Grounding: 5-4-3-2-1',
      rain.itemId,
      scan.itemId,
    ]);
    await store.idle();
    expect(store.value.keys, unorderedEquals([rain.itemId, scan.itemId]));
    expect(
      store.value.values.every((s) => s.status == DownloadStatus.done),
      isTrue,
    );
    expect(store.canDownload('tool:Grounding: 5-4-3-2-1'), isFalse);
  });

  test('remove deletes the file; remove all empties the folder', () async {
    final store = phone();
    await store.load();
    await store.downloadAll([rain.itemId, scan.itemId]);
    await store.idle();

    await store.remove(rain.itemId);
    expect(store.stateOf(rain.itemId).status, DownloadStatus.none);
    expect(await files.downloaded(rain.ref), isNull);
    expect(await files.downloaded(scan.ref), isNotNull);

    await store.removeAll();
    expect(store.value, isEmpty);
    expect(Directory('${root.path}/support/media').existsSync(), isFalse);
    expect(store.totalBytes, 0);
  });

  test('removing a download in progress cancels it', () async {
    final store = phone();
    await store.load();
    transfer.hold = Completer();
    await store.download(rain.itemId);
    await pumpEventQueue();
    await store.remove(rain.itemId);
    transfer.hold!.complete();
    await store.idle();
    expect(transfer.cancelled, ['media-${rain.ref.sha256}']);
    expect(store.stateOf(rain.itemId).status, DownloadStatus.none);
  });

  test('a loop fetched to play is kept as a download', () async {
    network.set([ConnectivityResult.mobile]);
    final store = phone();
    await store.load();
    final file = await store.fetchNow(rain);
    expect(file.readAsBytesSync(), rainBytes);
    expect(transfer.wifiOnlyAsked, [false], reason: 'playing is not waiting');
    expect(store.stateOf(rain.itemId).status, DownloadStatus.done);

    // The second play uses the copy.
    await store.fetchNow(rain);
    expect(transfer.fetched, hasLength(1));
  });

  testWidgets('the storage screen lists downloads and deletes them', (
    tester,
  ) async {
    final store = phone();
    final previous = DownloadStore.instance;
    DownloadStore.instance = store;
    addTearDown(() => DownloadStore.instance = previous);
    await tester.runAsync(() async {
      await store.load();
      await store.downloadAll([rain.itemId, scan.itemId]);
      await store.idle();
    });

    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const DownloadsScreen()),
    );
    await tester.pump();
    expect(find.text('Rainfall'), findsOneWidget);
    expect(find.text('Body scan'), findsOneWidget);
    expect(find.text(formatBytes(rainBytes.length)), findsOneWidget);
    expect(
      find.text(
        DownloadStrings.using(formatBytes(rainBytes.length + scanBytes.length)),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(store.wifiOnly.value, isFalse);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip(DownloadStrings.deleteOne('Rainfall')));
      await store.idle();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text('Rainfall'), findsNothing);
    expect(find.text('Body scan'), findsOneWidget);

    await tester.ensureVisible(find.text(DownloadStrings.deleteAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DownloadStrings.deleteAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DownloadStrings.delete));
    await tester.pumpAndSettle();
    // Deleting the files is real disk work, outside the test clock.
    for (var i = 0; i < 10 && store.value.isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump();
    expect(find.text(DownloadStrings.empty), findsOneWidget);
  });

  test('sizes read the way people say them', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(48000), '48 KB');
    expect(formatBytes(2400000), '2.4 MB');
  });
}
