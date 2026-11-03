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
import 'package:yournotalone/media/lapsed_downloads.dart';
import 'package:yournotalone/media/media_files.dart';
import 'package:yournotalone/media/media_links.dart';
import 'package:yournotalone/media/media_transfer.dart';

MediaEntry _entry(String id, List<int> bytes) {
  final sha = sha256.convert(bytes).toString();
  return MediaEntry(
    itemId: id,
    title: id.split(':').last,
    role: 'audio',
    path: 'assets/$id.m4a',
    ref: MediaRef(
      key: 'media/$sha.m4a',
      sha256: sha,
      bytes: bytes.length,
      premium: false,
    ),
  );
}

/// Serves whatever the "server" has for a URL path.
class _Transfer implements MediaTransfer {
  _Transfer(this.server);

  final Map<String, List<int>> server;

  @override
  Future<bool> fetch({
    required String id,
    required Uri url,
    required File file,
    required bool wifiOnly,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = server[url.path];
    if (bytes == null) return false;
    await file.writeAsBytes(bytes);
    return true;
  }

  @override
  Future<void> cancel(String id) async {}
}

class _Wifi implements NetworkStatus {
  @override
  Future<List<ConnectivityResult>> current() async => [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get changes => const Stream.empty();
}

void main() {
  final rainBytes = utf8.encode('rain on a tin roof');
  final scanBytes = utf8.encode('breathe in, breathe out, slowly');
  final rain = _entry('sound:Rainfall', rainBytes);
  final scan = _entry('meditation:Body scan', scanBytes);
  final catalog = {
    rain.itemId: [rain],
    scan.itemId: [scan],
  };
  // Body scan is premium, Rainfall free.
  bool isPremiumItem(String id) => id == scan.itemId;

  late Directory root;
  late DownloadStore store;
  late DateTime now;
  late bool premium;

  LapsedDownloads lapsed() => LapsedDownloads(
    clock: () => now,
    store: store,
    premium: () => premium,
    isPremiumItem: isPremiumItem,
  );

  Future<void> downloadBoth() async {
    await store.downloadAll([rain.itemId, scan.itemId]);
    await store.idle();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    root = Directory.systemTemp.createTempSync('lapsed_downloads_test');
    final files = MediaFiles(
      support: () async => Directory('${root.path}/support'),
      cache: () async => Directory('${root.path}/cache'),
    );
    store = DownloadStore.forTest(
      transfer: _Transfer({
        '/${rain.ref.key}': rainBytes,
        '/${scan.ref.key}': scanBytes,
      }),
      links: MediaLinks(apiUrl: '', baseUrl: 'https://cdn.test/'),
      files: files,
      network: _Wifi(),
      entriesFor: (id) => catalog[id] ?? const [],
    );
    now = DateTime.utc(2026, 11, 3, 9);
    premium = true;
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('never asks while premium is active, and notes it', () async {
    await downloadBoth();
    expect(await lapsed().due(), isNull);
    premium = false;
    now = now.add(const Duration(days: 29, hours: 23));
    expect(await lapsed().due(), isNull);
  });

  test('asks 30 days after premium was last seen, with the premium size '
      'only', () async {
    await downloadBoth();
    await lapsed().due();
    premium = false;
    now = now.add(LapsedDownloads.lapse);
    expect(await lapsed().due(), scanBytes.length);
  });

  test('nothing to ask without premium downloads', () async {
    await store.download(rain.itemId);
    await store.idle();
    await lapsed().due();
    premium = false;
    now = now.add(const Duration(days: 90));
    expect(await lapsed().due(), isNull);
  });

  test('with no record of premium, the 30 days start now', () async {
    await downloadBoth();
    premium = false;
    expect(await lapsed().due(), isNull);
    now = now.add(const Duration(days: 29));
    expect(await lapsed().due(), isNull);
    now = now.add(const Duration(days: 1));
    expect(await lapsed().due(), scanBytes.length);
  });

  test('"Keep" stops the question for another 30 days', () async {
    await downloadBoth();
    await lapsed().due();
    premium = false;
    now = now.add(const Duration(days: 31));
    await lapsed().keep();
    now = now.add(const Duration(days: 29));
    expect(await lapsed().due(), isNull);
    now = now.add(const Duration(days: 1));
    expect(await lapsed().due(), scanBytes.length);
  });

  test('premium again starts the count afresh', () async {
    await downloadBoth();
    await lapsed().due();
    premium = false;
    now = now.add(const Duration(days: 31));
    await lapsed().keep();
    premium = true;
    now = now.add(const Duration(days: 40));
    await lapsed().due();
    premium = false;
    now = now.add(const Duration(days: 10));
    expect(await lapsed().due(), isNull);
  });

  test('"Remove" deletes premium downloads and keeps free ones', () async {
    await downloadBoth();
    await lapsed().remove();
    expect(store.stateOf(scan.itemId).status, DownloadStatus.none);
    expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
    final (ids, bytes) = await lapsed().premiumDownloads();
    expect(ids, isEmpty);
    expect(bytes, 0);
  });

  group('the dialog', () {
    Future<void> show(WidgetTester tester, LapsedDownloads lapsed) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => lapsed.maybeAsk(context),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      // Real file I/O behind the store; let it finish outside fake time.
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 50 && find.byType(AlertDialog).evaluate().isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
    }

    Future<void> lapse() async {
      await downloadBoth();
      await lapsed().due();
      premium = false;
      now = now.add(LapsedDownloads.lapse);
    }

    testWidgets('shows the size; "Keep" keeps the files', (tester) async {
      await tester.runAsync(lapse);
      final l = lapsed();
      await show(tester, l);
      expect(find.text('Remove Premium downloads?'), findsOneWidget);
      expect(
        find.textContaining(formatBytes(scanBytes.length)),
        findsOneWidget,
      );
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.stateOf(scan.itemId).status, DownloadStatus.done);
      expect(await tester.runAsync(l.due), isNull);
    });

    testWidgets('"Remove" removes them', (tester) async {
      await tester.runAsync(lapse);
      await show(tester, lapsed());
      await tester.tap(find.text('Remove'));
      await tester.runAsync(() async {
        for (
          var i = 0;
          i < 100 && store.stateOf(scan.itemId).status != DownloadStatus.none;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(store.stateOf(scan.itemId).status, DownloadStatus.none);
      expect(store.stateOf(rain.itemId).status, DownloadStatus.done);
    });
  });
}
