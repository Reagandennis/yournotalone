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

MediaEntry _entry(
  String id,
  List<int> bytes, {
  String role = 'audio',
  bool premium = false,
}) {
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
      premium: premium,
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

  /// While set and not complete, a Wi-Fi only transfer waits, the way the
  /// system holds one off Wi-Fi, until it's cancelled.
  Completer<void>? wifi;
  final _wake = <String, Completer<void>>{};

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
    if (wifi case final w? when wifiOnly) {
      final wake = _wake[id] = Completer<void>();
      await Future.any([w.future, wake.future]);
    }
    if (cancelled.contains(id)) return false;
    await file.writeAsBytes(bytes);
    onProgress?.call(1);
    return true;
  }

  @override
  Future<void> cancel(String id) async {
    cancelled.add(id);
    if (_wake[id] case final w? when !w.isCompleted) w.complete();
  }
}

/// Links straight to the "server", premium or not.
class _FreeLinks extends MediaLinks {
  _FreeLinks() : super(apiUrl: '', baseUrl: 'https://cdn.test/');

  @override
  Future<Uri> urlFor(MediaEntry entry, MediaPurpose purpose) async =>
      Uri.parse('https://cdn.test/').resolve(entry.ref.key);
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

  /// A fresh store, as after the app starts, reading [items] (the
  /// catalogue above unless given) for an account with or without
  /// [premium].
  DownloadStore phone({
    Map<String, List<MediaEntry>>? items,
    bool premium = false,
    String? Function()? user,
    Stream<Object?>? userChanges,
  }) => DownloadStore.forTest(
    transfer: transfer,
    links: MediaLinks(apiUrl: '', baseUrl: 'https://cdn.test/'),
    files: files,
    network: network,
    entriesFor: (id) => (items ?? catalog)[id] ?? const [],
    isPremium: () => premium,
    userId: user,
    userChanges: userChanges,
  );

  File fileOf(MediaEntry e) =>
      File('${root.path}/support/media/${e.ref.sha256}.m4a');

  /// Waits for [until], failing rather than hanging if it never comes.
  Future<void> soon(bool Function() until) async {
    for (var i = 0; i < 200 && !until(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(until(), isTrue);
  }

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
    // Real file I/O sits between queueing and the first progress report,
    // so wait for it rather than for a fixed number of turns.
    for (var i = 0; i < 100 && store.stateOf(rain.itemId).progress < 0.5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
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

  group('a catalogue update that gives an item new audio', () {
    final newRainBytes = utf8.encode('rain on a tin roof, re-recorded');
    final newRain = _entry('sound:Rainfall', newRainBytes);
    final updated = {
      ...catalog,
      rain.itemId: [newRain],
    };

    setUp(() => transfer.server['/${newRain.ref.key}'] = newRainBytes);

    Future<void> downloadedBefore() async {
      final before = phone();
      await before.load();
      await before.download(rain.itemId);
      await before.idle();
      expect(fileOf(rain).existsSync(), isTrue);
      before.dispose();
    }

    test('fetches it again and deletes the old file', () async {
      await downloadedBefore();
      final store = phone(items: updated);
      await store.load();
      await store.idle();
      expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
      expect(fileOf(newRain).readAsBytesSync(), newRainBytes);
      expect(fileOf(rain).existsSync(), isFalse);
      expect(store.totalBytes, newRainBytes.length);
      expect(await files.downloaded(newRain.ref), isNotNull);
    });

    test('off Wi-Fi it waits like any download, not "Downloaded"', () async {
      await downloadedBefore();
      network.set([ConnectivityResult.mobile]);
      final store = phone(items: updated);
      await store.load();
      await store.idle();
      expect(store.stateOf(rain.itemId).status, DownloadStatus.queued);
      expect(store.waiting.value, isTrue);
      expect(fileOf(rain).existsSync(), isFalse);
      expect(store.totalBytes, 0);
    });

    test('premium audio is not fetched again without Premium', () async {
      final stormBytes = utf8.encode('thunder');
      final storm = _entry('sound:Distant storm', stormBytes, premium: true);
      final newStorm = _entry(
        'sound:Distant storm',
        utf8.encode('thunder, louder'),
        premium: true,
      );
      transfer.server['/${storm.ref.key}'] = stormBytes;
      DownloadStore account(MediaEntry e, {required bool premium}) =>
          DownloadStore.forTest(
            transfer: transfer,
            // Signing is beside the point here.
            links: _FreeLinks(),
            files: files,
            network: network,
            entriesFor: (id) => id == e.itemId ? [e] : const [],
            isPremium: () => premium,
          );

      final before = account(storm, premium: true);
      await before.load();
      await before.download(storm.itemId);
      await before.idle();
      expect(before.stateOf(storm.itemId).status, DownloadStatus.done);
      before.dispose();
      final fetches = transfer.fetched.length;

      final lapsed = account(newStorm, premium: false);
      await lapsed.load();
      await lapsed.idle();
      expect(lapsed.stateOf(storm.itemId).status, DownloadStatus.none);
      expect(fileOf(storm).existsSync(), isFalse);
      expect(transfer.fetched, hasLength(fetches));
    });

    test('playing it fetches the new audio and lets the old go', () async {
      // The catalogue changes under a store that has already loaded.
      var items = catalog;
      final store = DownloadStore.forTest(
        transfer: transfer,
        links: MediaLinks(apiUrl: '', baseUrl: 'https://cdn.test/'),
        files: files,
        network: network,
        entriesFor: (id) => items[id] ?? const [],
      );
      await store.load();
      await store.download(rain.itemId);
      await store.idle();
      items = updated;
      await store.fetchNow(newRain);
      expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
      expect(fileOf(rain).existsSync(), isFalse);
      expect(store.totalBytes, newRainBytes.length);
    });
  });

  test('files no download uses are deleted, so the total is the disk', () async {
    final orphan = fileOf(_entry('sound:Gone', utf8.encode('old')));
    orphan
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(utf8.encode('old'));
    final half = File('${orphan.path}.part')..writeAsBytesSync([1]);
    final stranger = File('${orphan.parent.path}/notes.txt')
      ..writeAsStringSync('not ours');
    final first = phone();
    await first.load();
    await first.download(rain.itemId);
    await first.idle();
    first.dispose();
    // Left by a transfer that was stopped when another took over.
    final stopped = File('${fileOf(rain).path}.part')..writeAsBytesSync([2]);

    final store = phone();
    await store.load();
    expect(orphan.existsSync(), isFalse);
    expect(half.existsSync(), isFalse);
    expect(stopped.existsSync(), isFalse);
    expect(fileOf(rain).existsSync(), isTrue);
    expect(stranger.existsSync(), isTrue, reason: 'not a name we give');
    expect(store.totalBytes, rainBytes.length);
  });

  group('Wi-Fi only never holds up playing', () {
    /// A queued download the system is holding until there's Wi-Fi.
    Future<DownloadStore> held() async {
      transfer.wifi = Completer();
      final store = phone();
      await store.load();
      await store.download(rain.itemId);
      await soon(() => transfer.fetched.isNotEmpty);
      network.set([ConnectivityResult.mobile]);
      await pumpEventQueue();
      expect(store.stateOf(rain.itemId).status, DownloadStatus.downloading);
      return store;
    }

    test('playing now starts again on any connection', () async {
      final store = await held();
      final file = await store
          .fetchNow(rain)
          .timeout(const Duration(seconds: 5));
      expect(file.readAsBytesSync(), rainBytes);
      expect(transfer.wifiOnlyAsked, [true, false]);
      expect(transfer.cancelled, contains('media-${rain.ref.sha256}'));
      // The queue had been waiting on the held one: it carries on too.
      await store.idle().timeout(const Duration(seconds: 5));
      expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
    });

    test('turning Wi-Fi only off lets a held download go', () async {
      final store = await held();
      await store.setWifiOnly(false);
      await store.idle().timeout(const Duration(seconds: 5));
      expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
      expect(transfer.wifiOnlyAsked, [true, false]);
      expect(fileOf(rain).readAsBytesSync(), rainBytes);
      expect(
        Directory('${root.path}/support/media').listSync().map((f) => f.path),
        [fileOf(rain).path],
        reason: 'no part file left behind',
      );
    });
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

  group('on a shared phone', () {
    late String? signedIn;
    late StreamController<Object?> auth;

    setUp(() {
      signedIn = 'amina';
      auth = StreamController<Object?>.broadcast();
    });
    tearDown(() => auth.close());

    DownloadStore shared() =>
        phone(user: () => signedIn, userChanges: auth.stream);

    Future<void> signIn(String? user) async {
      signedIn = user;
      auth.add(null);
      await pumpEventQueue();
    }

    test('the next person does not see the last one\'s downloads', () async {
      final store = shared();
      await store.load();
      await store.download(rain.itemId);
      await store.idle();
      expect(store.stateOf(rain.itemId).status, DownloadStatus.done);

      await signIn(null);
      expect(store.value, isEmpty);
      await signIn('bo');
      expect(store.value, isEmpty);
      expect(store.downloaded, isEmpty);
      expect(store.totalBytes, 0);

      // Bo downloading the same item shares the file, with nothing fetched.
      final fetches = transfer.fetched.length;
      await store.download(rain.itemId);
      await store.idle();
      expect(transfer.fetched.length, fetches);
      expect(store.stateOf(rain.itemId).status, DownloadStatus.done);

      // Bo deleting it leaves Amina's copy.
      await store.remove(rain.itemId);
      expect(store.stateOf(rain.itemId).status, DownloadStatus.none);
      expect(await files.downloaded(rain.ref), isNotNull);
      await signIn('amina');
      expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
    });

    test('downloads from before go to whoever signs in first', () async {
      signedIn = null;
      final before = shared();
      await before.load();
      await before.download(rain.itemId);
      await before.idle();
      await before.reset();

      signedIn = 'amina';
      final store = shared();
      await store.load();
      expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
      await signIn('bo');
      expect(store.value, isEmpty);
    });

    test('a deleted account\'s downloads go; someone else\'s stay', () async {
      final store = shared();
      await store.load();
      await store.downloadAll([rain.itemId, scan.itemId]);
      await store.idle();
      await signIn('bo');
      await store.download(scan.itemId);
      await store.idle();

      await store.forgetUser('amina');
      expect(await files.downloaded(rain.ref), isNull);
      expect(await files.downloaded(scan.ref), isNotNull, reason: 'Bo\'s');
      await signIn('amina');
      expect(store.value, isEmpty);
    });
  });

  test('removing a download that is playing deletes it once let go',
      () async {
    final store = phone();
    await store.load();
    await store.download(rain.itemId);
    await store.idle();

    store.hold(rain.ref.sha256);
    await store.remove(rain.itemId);
    expect(store.stateOf(rain.itemId).status, DownloadStatus.none);
    expect(await files.downloaded(rain.ref), isNotNull, reason: 'playing');
    await store.release(rain.ref.sha256);
    expect(await files.downloaded(rain.ref), isNull);
  });

  test('a loop removed while it is fetched to play is not kept', () async {
    network.set([ConnectivityResult.mobile]);
    final store = phone();
    await store.load();
    transfer.hold = Completer();
    final playing = store
        .fetchNow(rain)
        .then<File?>((f) => f, onError: (Object _) => null);
    await pumpEventQueue();
    await store.remove(rain.itemId);
    transfer.hold!.complete();
    await playing;
    await store.idle();
    expect(store.stateOf(rain.itemId).status, DownloadStatus.none);
    expect(store.downloaded, isEmpty);
  });

  test('remove all stops transfers before emptying the folder', () async {
    final store = phone();
    await store.load();
    transfer.hold = Completer();
    await store.downloadAll([rain.itemId, scan.itemId]);
    await pumpEventQueue();
    await store.removeAll();
    transfer.hold!.complete();
    await store.idle();
    expect(transfer.cancelled, contains('media-${rain.ref.sha256}'));
    expect(store.value, isEmpty);
    expect(await files.downloaded(rain.ref), isNull);
  });

  test('sizes read the way people say them', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(48000), '48 KB');
    expect(formatBytes(2400000), '2.4 MB');
  });
}
