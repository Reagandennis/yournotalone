import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';

Map<String, dynamic> _bundledJson() =>
    jsonDecode(File(bundledCatalogAsset).readAsStringSync())
        as Map<String, dynamic>;

/// The bundled snapshot republished as [version].
Map<String, dynamic> _published(
  int version, {
  String hash = 'feedc0de12345678',
}) => _bundledJson()
  ..['version'] = version
  ..['hash'] = hash
  ..['media'] = {
    'sound:Rainfall': {
      'audio': {
        'key': 'media/abc.m4a',
        'sha256': 'abc',
        'bytes': 1234,
        'access': 'premium',
      },
    },
  };

/// Serves `latest.json` and the snapshot it points to; counts requests.
class _Server {
  _Server({
    this.version = 5,
    this.minApp = '1.1.0',
    String? pathHash,
    this.down = false,
  }) : pathHash = pathHash ?? 'feedc0de12345678';

  final int version;
  final String minApp;
  final String pathHash;
  final bool down;
  final requests = <String>[];

  late final client = MockClient((req) async {
    requests.add(req.url.path);
    if (down) throw const SocketException('offline');
    if (req.url.path == '/catalog/latest.json') {
      return http.Response(
        jsonEncode({
          'version': version,
          'path': 'catalog/v$version-$pathHash.json',
          'minApp': minApp,
        }),
        200,
      );
    }
    if (req.url.path == '/catalog/v$version-$pathHash.json') {
      return http.Response.bytes(
        utf8.encode(jsonEncode(_published(version))),
        200,
      );
    }
    return http.Response('not found', 404);
  });
}

void main() {
  final bundled = CatalogSnapshot.fromJson(_bundledJson())!;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => bundledAssetsForTest = null);

  Future<ContentCatalog> started(_Server server, {String app = '1.1.0'}) async {
    final catalog = ContentCatalog.forTest(
      client: server.client,
      appVersion: app,
    );
    await catalog.loadFrom(bundled);
    return catalog;
  }

  test(
    'downloads a newer catalogue and uses it from the next launch',
    () async {
      final server = _Server();
      final catalog = await started(server);
      expect(await catalog.refresh(), isTrue);
      expect(catalog.version, 0, reason: 'nothing changes mid-session');

      final nextLaunch = await started(server);
      expect(nextLaunch.version, 5);
      expect(nextLaunch.items, hasLength(bundled.items.length));
    },
  );

  test('skips a catalogue that is not newer', () async {
    final server = _Server(version: 0);
    final catalog = await started(server);
    expect(await catalog.refresh(), isFalse);
    expect(server.requests, ['/catalog/latest.json']);
  });

  test('skips a catalogue that needs a newer app', () async {
    final server = _Server(minApp: '1.2.0');
    final catalog = await started(server, app: '1.1.0');
    expect(await catalog.refresh(), isFalse);
    expect((await started(server)).version, 0);
  });

  test('rejects a file that is not the one latest.json names', () async {
    final server = _Server(pathHash: '0000000000000000');
    final catalog = await started(server);
    expect(await catalog.refresh(), isFalse);
    expect((await started(server)).version, 0);
  });

  test('offline, keeps what it has', () async {
    final catalog = await started(_Server(down: true));
    expect(await catalog.refresh(), isFalse);
    expect(catalog.version, 0);
  });

  test('a damaged download falls back to the bundled catalogue', () async {
    SharedPreferences.setMockInitialValues({'catalog.snapshot': '{not json'});
    final catalog = await started(_Server());
    expect(catalog.version, 0);
    expect(catalog.items, isNotEmpty);
  });

  test('reads the media map of a published catalogue', () {
    final snapshot = CatalogSnapshot.fromJson(_published(5))!;
    final ref = snapshot.media['sound:Rainfall']!['audio']!;
    expect(ref.key, 'media/abc.m4a');
    expect(ref.premium, isTrue);
    expect(bundled.media, isEmpty);
  });

  test('leaves out a sound whose audio this build does not have', () {
    bundledAssetsForTest = {
      for (final s in soundsCatalog)
        if (s.title != 'Rainfall') s.asset,
    };
    final items = contentItemsFrom(bundled);
    expect(items.any((i) => i.id == 'sound:Rainfall'), isFalse);
    expect(items.any((i) => i.id == 'sound:Fireside'), isTrue);
  });

  test('compares app versions', () {
    expect(appVersionAtLeast('1.1.0', '1.1.0'), isTrue);
    expect(appVersionAtLeast('1.1.0+8', '1.1.0'), isTrue);
    expect(appVersionAtLeast('1.2.0', '1.10.0'), isFalse);
    expect(appVersionAtLeast('2.0', '1.9.9'), isTrue);
  });
}
