// StreamAudioSource is experimental in just_audio; see narration_stream.dart.
// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_audio/just_audio.dart';

import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/media/media_files.dart';
import 'package:yournotalone/media/media_links.dart';
import 'package:yournotalone/media/media_source.dart';
import 'package:yournotalone/media/narration_stream.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';

String _sha(List<int> bytes) => sha256.convert(bytes).toString();

MediaEntry _entry(
  String id,
  List<int> bytes, {
  bool premium = false,
  String role = 'audio',
  String? path,
}) {
  final sha = _sha(bytes);
  return MediaEntry(
    itemId: id,
    title: id,
    role: role,
    path: path ?? 'assets/sounds/$id.m4a',
    ref: MediaRef(
      key: '${premium ? 'private/' : ''}media/$sha.m4a',
      sha256: sha,
      bytes: bytes.length,
      premium: premium,
    ),
  );
}

/// Serves [bytes] the way LockCachingAudioSource would, for the proxy.
class _Bytes extends StreamAudioSource {
  _Bytes(this.bytes);

  final List<int> bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0, to = end ?? bytes.length;
    return StreamAudioResponse(
      sourceLength: start == null ? null : bytes.length,
      contentLength: to - from,
      offset: start,
      contentType: 'audio/mp4',
      stream: Stream.value(bytes.sublist(from, to)),
    );
  }
}

void main() {
  late Directory root;
  late MediaFiles files;

  setUp(() {
    root = Directory.systemTemp.createTempSync('media_test');
    files = MediaFiles(
      support: () async => Directory('${root.path}/support'),
      cache: () async => Directory('${root.path}/cache'),
    );
  });

  tearDown(() {
    bundledAssetsForTest = null;
    root.deleteSync(recursive: true);
  });

  Future<File> put(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  group('source resolution', () {
    final bytes = utf8.encode('rain on a tin roof');
    final rain = _entry('sound:Rainfall', bytes);

    MediaResolver resolver({required Set<String> bundled}) => MediaResolver(
      isBundled: bundled.contains,
      lookup: (path) => path == rain.path ? rain : null,
      files: files,
    );

    test('a bundled asset plays from the app, even if downloaded', () async {
      await put(await files.downloadFor(rain.ref.sha256), bytes);
      final origin = await resolver(bundled: {rain.path}).resolve(rain.path);
      expect(origin, isA<BundledAudio>());
    });

    test('then a download', () async {
      final file = await put(await files.downloadFor(rain.ref.sha256), bytes);
      final origin = await resolver(bundled: {}).resolve(rain.path);
      expect(origin, isA<LocalAudio>());
      expect((origin as LocalAudio).file.path, file.path);
    });

    test('then the network', () async {
      final origin = await resolver(bundled: {}).resolve(rain.path);
      expect(origin, isA<RemoteAudio>());
      expect((origin as RemoteAudio).entry, same(rain));
    });

    test('a half-written download is not played', () async {
      await put(await files.downloadFor(rain.ref.sha256), bytes.sublist(4));
      final origin = await resolver(bundled: {}).resolve(rain.path);
      expect(origin, isA<RemoteAudio>());
    });

    test('nothing for a path that is neither bundled nor published', () async {
      expect(await resolver(bundled: {}).resolve('assets/x.m4a'), isNull);
    });

    test('downloads are named after the sha256', () async {
      final file = await files.downloadFor(rain.ref.sha256);
      expect(file.path, '${root.path}/support/media/${rain.ref.sha256}.m4a');
      final cache = await files.streamCacheFor(rain.ref.sha256);
      expect(cache.path, '${root.path}/cache/narration/${rain.ref.sha256}.m4a');
    });
  });

  group('sha256 check', () {
    test('keeps a file that matches', () async {
      final bytes = utf8.encode('the right bytes');
      final file = await put(File('${root.path}/a.m4a'), bytes);
      expect(await verifyFile(file, _sha(bytes)), isTrue);
      expect(file.existsSync(), isTrue);
    });

    test('deletes a file that does not', () async {
      final file = await put(File('${root.path}/b.m4a'), [1, 2, 3]);
      expect(await verifyFile(file, _sha([1, 2, 4])), isFalse);
      expect(file.existsSync(), isFalse);
    });

    test('a damaged stream cache is deleted and streamed again', () async {
      final bytes = utf8.encode('breathe in');
      final scan = _entry('meditation:Body scan', bytes, role: 'narration');
      final cache = await put(
        await files.streamCacheFor(scan.ref.sha256),
        utf8.encode('breathe ou'),
      );
      final proxy = NarrationProxy();
      addTearDown(proxy.close);
      final url = await narrationUrl(
        scan,
        files: files,
        links: MediaLinks(baseUrl: 'https://cdn.test/'),
        proxy: proxy,
      );
      expect(cache.existsSync(), isFalse);
      expect(url.scheme, 'http');
      expect(url.host, '127.0.0.1');
    });

    test('a whole stream cache is played from the phone', () async {
      final bytes = utf8.encode('breathe in');
      final scan = _entry('meditation:Body scan', bytes, role: 'narration');
      final cache = await put(
        await files.streamCacheFor(scan.ref.sha256),
        bytes,
      );
      final url = await narrationUrl(
        scan,
        files: files,
        links: MediaLinks(baseUrl: 'https://cdn.test/'),
      );
      expect(url, Uri.file(cache.path));
    });
  });

  group('links', () {
    final free = _entry('sound:Rainfall', [1, 2, 3]);
    final premium = _entry('sound:Fireside', [4, 5, 6], premium: true);
    final expires = DateTime.utc(2026, 11, 2, 18);

    Map<String, dynamic> answer(MediaEntry e, {String? sha}) => {
      'urls': {
        e.itemId: {
          'audio': {
            'url': 'https://r2.test/${e.ref.key}?X-Amz-Signature=abc',
            'expires': expires.toIso8601String(),
            'sha256': sha ?? e.ref.sha256,
            'bytes': e.ref.bytes,
          },
        },
      },
      'missing': <String>[],
    };

    test('parses a sign answer', () {
      final result = parseSignResponse({
        'urls': {
          'sound:Rainfall': {
            'audio': {
              'url': 'https://cdn.test/media/abc.m4a',
              'expires': null,
              'sha256': 'abc',
              'bytes': 12,
            },
          },
          'meditation:Body scan': {
            'narration': {
              'url': 'https://r2.test/private/media/def.m4a?X-Amz-Expires=3600',
              'expires': '2026-11-02T18:00:00.000Z',
              'sha256': 'def',
              'bytes': 34,
            },
          },
        },
        'missing': ['sound:Gone'],
      });
      final rain = result.urls['sound:Rainfall']!['audio']!;
      expect(rain.url.toString(), 'https://cdn.test/media/abc.m4a');
      expect(rain.expires, isNull, reason: 'public links do not expire');
      final scan = result.urls['meditation:Body scan']!['narration']!;
      expect(scan.expires, DateTime.utc(2026, 11, 2, 18));
      expect(scan.url.queryParameters['X-Amz-Expires'], '3600');
      expect(scan.bytes, 34);
      expect(result.missing, ['sound:Gone']);
    });

    test('free audio comes straight from the CDN, no Worker', () async {
      var calls = 0;
      final links = MediaLinks(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
        apiUrl: '',
        baseUrl: 'https://cdn.test/',
      );
      final url = await links.urlFor(free, MediaPurpose.download);
      expect(url.toString(), 'https://cdn.test/${free.ref.key}');
      expect(calls, 0);
    });

    test('premium audio is signed with the account token', () async {
      late http.Request sent;
      final links = MediaLinks(
        client: MockClient((req) async {
          sent = req;
          return http.Response(jsonEncode(answer(premium)), 200);
        }),
        apiUrl: 'https://api.test',
        token: () => 'jwt-123',
        clock: () => DateTime.utc(2026, 11, 2, 12),
      );
      final url = await links.urlFor(premium, MediaPurpose.stream);
      expect(url.host, 'r2.test');
      expect(sent.url.toString(), 'https://api.test/v1/media/sign');
      expect(sent.headers['Authorization'], 'Bearer jwt-123');
      expect(jsonDecode(sent.body), {
        'items': ['sound:Fireside'],
        'purpose': 'stream',
      });
    });

    test('a signed link is reused until it nearly expires', () async {
      var calls = 0;
      var now = DateTime.utc(2026, 11, 2, 12);
      final links = MediaLinks(
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(answer(premium)), 200);
        }),
        apiUrl: 'https://api.test',
        token: () => 'jwt',
        clock: () => now,
      );
      await links.urlFor(premium, MediaPurpose.stream);
      await links.urlFor(premium, MediaPurpose.stream);
      expect(calls, 1);
      now = expires.subtract(const Duration(minutes: 1));
      await links.urlFor(premium, MediaPurpose.stream);
      expect(calls, 2);
    });

    test('403 means Premium is needed', () async {
      final links = MediaLinks(
        client: MockClient(
          (_) async => http.Response('{"error":"premium_required"}', 403),
        ),
        apiUrl: 'https://api.test',
        token: () => 'jwt',
      );
      expect(
        links.urlFor(premium, MediaPurpose.download),
        throwsA(isA<PremiumRequired>()),
      );
    });

    test('premium audio is unavailable without the Worker or signed out', () {
      expect(
        MediaLinks(
          apiUrl: '',
          token: () => 'jwt',
        ).urlFor(premium, MediaPurpose.download),
        throwsA(isA<MediaUnavailable>()),
      );
      expect(
        MediaLinks(
          apiUrl: 'https://api.test',
          token: () => null,
        ).urlFor(premium, MediaPurpose.download),
        throwsA(isA<MediaUnavailable>()),
      );
    });

    test('a link to a different file than this catalogue names is refused', () {
      final links = MediaLinks(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode(answer(premium, sha: 'other')), 200),
        ),
        apiUrl: 'https://api.test',
        token: () => 'jwt',
      );
      expect(
        links.urlFor(premium, MediaPurpose.download),
        throwsA(isA<MediaUnavailable>()),
      );
    });

    test('offline is unavailable, not a crash', () {
      final links = MediaLinks(
        client: MockClient((_) async => throw const SocketException('down')),
        apiUrl: 'https://api.test',
        token: () => 'jwt',
      );
      expect(
        links.urlFor(premium, MediaPurpose.download),
        throwsA(isA<MediaUnavailable>()),
      );
    });
  });

  group('narration proxy', () {
    test('reads range headers', () {
      expect(parseRange(null), isNull);
      expect(parseRange('bytes=0-1'), (0, 2));
      expect(parseRange('bytes=100-'), (100, null));
      expect(parseRange('items=1-2'), isNull);
    });

    test('answers whole and range requests', () async {
      final bytes = List.generate(100, (i) => i);
      final proxy = NarrationProxy();
      addTearDown(proxy.close);
      final url = await proxy.serve('abc', _Bytes(bytes));
      final client = HttpClient();
      addTearDown(client.close);

      final whole = await (await client.getUrl(url)).close();
      expect(whole.statusCode, 200);
      expect(await whole.expand((b) => b).toList(), bytes);

      final req = await client.getUrl(url);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=10-19');
      final part = await req.close();
      expect(part.statusCode, 206);
      expect(
        part.headers.value(HttpHeaders.contentRangeHeader),
        'bytes 10-19/100',
      );
      expect(await part.expand((b) => b).toList(), bytes.sublist(10, 20));

      final missing = await (await client.getUrl(
        url.replace(path: '/nope.m4a'),
      )).close();
      expect(missing.statusCode, 404);
      await missing.drain<void>();
    });
  });

  group('catalogue', () {
    Map<String, dynamic> bundledJson() =>
        jsonDecode(File(bundledCatalogAsset).readAsStringSync())
            as Map<String, dynamic>;

    test('an item whose audio is only published stays playable', () {
      final json = bundledJson()
        ..['media'] = {
          'sound:Rainfall': {
            'audio': {
              'key': 'private/media/abc.m4a',
              'sha256': 'abc',
              'bytes': 10,
              'access': 'premium',
            },
          },
        };
      final snapshot = CatalogSnapshot.fromJson(json)!;
      bundledAssetsForTest = {
        for (final s in soundsCatalog)
          if (s.title != 'Rainfall') s.asset,
      };
      final items = contentItemsFrom(snapshot);
      expect(items.any((i) => i.id == 'sound:Rainfall'), isTrue);

      final entries = mediaEntriesFrom(snapshot);
      expect(entries, hasLength(1));
      expect(entries.single.path, 'assets/sounds/rainfall.m4a');
      expect(entries.single.remote, isTrue);
    });

    test('the catalogue finds media by item and by path', () {
      final json = bundledJson()
        ..['media'] = {
          'sound:Rainfall': {
            'audio': {
              'key': 'media/abc.m4a',
              'sha256': 'abc',
              'bytes': 10,
              'access': 'public',
            },
          },
        };
      final catalog = ContentCatalog.forTest(
        client: MockClient((_) async => http.Response('', 404)),
        appVersion: '1.1.0',
      )..use(CatalogSnapshot.fromJson(json)!);
      expect(
        catalog.mediaAt('assets/sounds/rainfall.m4a')?.itemId,
        'sound:Rainfall',
      );
      bundledAssetsForTest = {};
      expect(catalog.downloadableFor('sound:Rainfall'), hasLength(1));
      bundledAssetsForTest = {'assets/sounds/rainfall.m4a'};
      expect(
        catalog.downloadableFor('sound:Rainfall'),
        isEmpty,
        reason: 'nothing to download when the app has it',
      );
    });
  });
}
