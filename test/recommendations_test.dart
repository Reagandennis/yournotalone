import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/discover/recommendations.dart';

const _base = 'https://api.test';

/// Answers POST /v1/recommendations; records what was sent.
class _Worker {
  _Worker({this.status = 200, List<String>? ids})
    : ids = ids ?? const ['tool:Grounding: 5-4-3-2-1', 'sound:Rainfall'];

  int status;
  bool down = false;
  List<String> ids;
  final requests = <http.Request>[];

  late final client = MockClient((req) async {
    requests.add(req);
    if (down) throw const SocketException('offline');
    if (req.url.path != '/v1/recommendations') {
      return http.Response('not found', 404);
    }
    return http.Response(
      jsonEncode({
        'items': [
          for (final id in ids) {'id': id, 'reason': 'For right now'},
        ],
        'rules': 'v1',
        'catalogVersion': 7,
      }),
      status,
    );
  });

  RecommendationsClient connect({String? token = 'jwt', String base = _base}) =>
      RecommendationsClient.forTest(
        client: client,
        baseUrl: base,
        token: () async => token,
      );
}

final _evening = DateTime(2026, 11, 2, 19, 30);

RecommendationRequest _request({
  DateTime? now,
  int? lastMood,
  DateTime? lastMoodAt,
  String? courseId,
  int? courseDay,
}) => RecommendationRequest(
  now: now ?? _evening,
  account: 'user-1',
  lastMood: lastMood,
  lastMoodAt: lastMoodAt,
  opensByKind: const {'sound': 4},
  courseId: courseId,
  courseDay: courseDay,
  catalogVersion: 7,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RecommendationsClient', () {
    test('is off, and calls nothing, without a Worker URL', () async {
      final worker = _Worker();
      final client = worker.connect(base: '');
      expect(client.enabled, isFalse);
      expect(await client.fetch(_request()), isNull);
      expect(worker.requests, isEmpty);
    });

    test('is off in a build without MEDIA_API_URL', () {
      expect(recommendationsBaseUrl, isEmpty);
      expect(RecommendationsClient.instance.enabled, isFalse);
    });

    test('posts the device signals with the access token', () async {
      final worker = _Worker();
      final picks = await worker.connect().fetch(
        _request(
          lastMood: 0,
          lastMoodAt: DateTime.utc(2026, 11, 2, 16, 0),
          courseId: 'sleep7',
          courseDay: 2,
        ),
      );
      expect(
        [for (final p in picks!) p.id],
        ['tool:Grounding: 5-4-3-2-1', 'sound:Rainfall'],
      );
      expect(picks.first.reason, 'For right now');

      final req = worker.requests.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), '$_base/v1/recommendations');
      expect(req.headers['Authorization'], 'Bearer jwt');
      expect(jsonDecode(req.body), {
        'surface': 'home',
        'localTime': '2026-11-02T19:30',
        'locale': 'en',
        'catalogVersion': 7,
        'lastMood': 0,
        'lastMoodAt': '2026-11-02T16:00:00.000Z',
        'opensByKind': {'sound': 4},
        'course': {'id': 'sleep7', 'day': 2},
        'limit': 6,
      });
    });

    test('keeps the answer for 3 hours', () async {
      final worker = _Worker();
      final client = worker.connect();
      final morning = DateTime(2026, 11, 2, 5, 30);
      await client.fetch(_request(now: morning));
      await client.fetch(
        _request(now: morning.add(const Duration(minutes: 50))),
      );
      expect(worker.requests, hasLength(1));
      // Still the morning, but past 3 hours: asks again.
      await client.fetch(
        _request(now: morning.add(const Duration(hours: 3, minutes: 1))),
      );
      expect(worker.requests, hasLength(2));
    });

    test('asks again after a hard check-in, a course step or a new hour '
        'bracket', () async {
      final worker = _Worker();
      final client = worker.connect();
      await client.fetch(_request());
      await client.fetch(_request(lastMood: 1, lastMoodAt: _evening));
      await client.fetch(_request(courseId: 'sleep7', courseDay: 0));
      await client.fetch(_request(now: DateTime(2026, 11, 2, 22)));
      expect(worker.requests, hasLength(4));
    });

    test('an okay check-in alone does not', () async {
      final worker = _Worker();
      final client = worker.connect();
      await client.fetch(_request());
      await client.fetch(_request(lastMood: 3, lastMoodAt: _evening));
      expect(worker.requests, hasLength(1));
    });

    test('falls back to the last answer when the Worker fails', () async {
      final worker = _Worker();
      final client = worker.connect();
      await client.fetch(_request(now: DateTime(2026, 11, 2, 5)));
      worker.down = true;
      final later = DateTime(2026, 11, 2, 11, 30);
      final picks = await client.fetch(_request(now: later));
      expect(worker.requests, hasLength(2));
      expect(picks, hasLength(2));
    });

    test('null (the on-device order) when the Worker fails and there is no '
        'matching answer', () async {
      final worker = _Worker(status: 500);
      expect(await worker.connect().fetch(_request()), isNull);
      worker
        ..status = 200
        ..down = true;
      expect(await worker.connect().fetch(_request()), isNull);
    });

    test('a cached answer from another account is not used', () async {
      final worker = _Worker();
      await worker.connect().fetch(_request());
      worker.down = true;
      final other = RecommendationRequest(now: _evening, account: 'user-2');
      expect(await worker.connect().fetch(other), isNull);
    });

    test('signed out: no call', () async {
      final worker = _Worker();
      expect(await worker.connect(token: null).fetch(_request()), isNull);
      expect(worker.requests, isEmpty);
    });

    test('a malformed answer counts as a failure', () async {
      final client = RecommendationsClient.forTest(
        client: MockClient((_) async => http.Response('{"nope":1}', 200)),
        baseUrl: _base,
        token: () async => 'jwt',
      );
      expect(await client.fetch(_request()), isNull);
    });

    test('remembers the last check-in and its time', () async {
      final client = _Worker().connect();
      expect(await RecommendationsClient.lastMood(), isNull);
      await client.noteMood(0, at: DateTime.utc(2026, 11, 2, 16));
      expect(await RecommendationsClient.lastMood(), (
        0,
        DateTime.utc(2026, 11, 2, 16),
      ));
    });
  });

  group('RecommendationRequest', () {
    test('distressed: awful or low, within 2 hours or with no time', () {
      final at = _evening;
      expect(_request().distressed, isFalse);
      expect(_request(lastMood: 0, lastMoodAt: at).distressed, isTrue);
      expect(_request(lastMood: 1).distressed, isTrue);
      expect(_request(lastMood: 2, lastMoodAt: at).distressed, isFalse);
      expect(
        _request(
          lastMood: 0,
          lastMoodAt: at.subtract(const Duration(hours: 2, minutes: 1)),
        ).distressed,
        isFalse,
      );
    });

    test('leaves out what it does not know', () {
      final json = RecommendationRequest(now: _evening).toJson();
      expect(json.keys, [
        'surface',
        'localTime',
        'locale',
        'opensByKind',
        'limit',
      ]);
    });
  });

  group('itemsForRecommendations', () {
    final index = [
      for (final title in ['A', 'B', 'C', 'D'])
        ContentItem(
          kind: ContentKind.tool,
          title: title,
          blurb: '',
          icon: ContentKind.tool.icon,
          accent: const Color(0xFF000000),
          premium: false,
          open: (_) {},
        ),
    ];
    List<String>? ids(List<String>? picks, {Set<String> exclude = const {}}) =>
        itemsForRecommendations(
          picks == null
              ? null
              : [for (final id in picks) Recommendation(id, '')],
          exclude: exclude,
          count: 2,
          from: index,
        )?.map((i) => i.id).toList();

    test('maps ids to items, in order, skipping unknown and excluded ones', () {
      expect(
        ids(['tool:C', 'sound:Gone', 'tool:A', 'tool:B'], exclude: {'tool:A'}),
        ['tool:C', 'tool:B'],
      );
    });

    test('null when there is nothing to show', () {
      expect(ids(null), isNull);
      expect(ids(['sound:Gone']), isNull);
    });
  });
}
