/// Home's suggestions from the Worker's `POST /v1/recommendations` (see
/// docs/backend-design.md §5), which adds what only the server can see:
/// session history and feelings from every device, saves, and what's
/// popular. The on-device order ([recommend]) stays the fallback, and is
/// all there is when the app is built without `MEDIA_API_URL`.
///
/// The answer is kept for 3 hours, as long as the time of day, a
/// distressed check-in and the course in progress haven't changed, so
/// opening Home again doesn't call the Worker each time.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../content/content_catalog.dart';
import '../courses/course_progress.dart';
import 'content_index.dart';
import 'usage_store.dart';

/// The Worker's base URL, shared with media signing. Empty means off.
const recommendationsBaseUrl = String.fromEnvironment('MEDIA_API_URL');

/// One suggestion: an item id and a short line saying why.
class Recommendation {
  const Recommendation(this.id, this.reason);

  final String id;
  final String reason;
}

/// What the device knows that the server doesn't. Nothing in it is stored
/// on the server.
class RecommendationRequest {
  const RecommendationRequest({
    required this.now,
    this.account,
    this.lastMood,
    this.lastMoodAt,
    this.opensByKind = const {},
    this.courseId,
    this.courseDay,
    this.catalogVersion,
  });

  /// Gathers it from the stores Home already uses.
  static Future<RecommendationRequest> current({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final mood = await RecommendationsClient.lastMood();
    final course = CourseStore.instance.active;
    return RecommendationRequest(
      now: at,
      account: Supabase.instance.client.auth.currentUser?.id,
      lastMood: mood?.$1,
      lastMoodAt: mood?.$2,
      opensByKind: await UsageStore.instance.openCounts(),
      courseId: course?.id,
      courseDay: course == null
          ? null
          : CourseStore.instance.of(course).nextDay(course),
      catalogVersion: ContentCatalog.instance.version,
    );
  }

  final DateTime now;

  /// Whose answer it is; only used to keep cached answers apart.
  final String? account;
  final int? lastMood;
  final DateTime? lastMoodAt;
  final Map<String, int> opensByKind;
  final String? courseId;
  final int? courseDay;
  final int? catalogVersion;

  /// Awful or low within the last 2 hours: the server's safety rules apply.
  bool get distressed =>
      lastMood != null &&
      lastMood! <= 1 &&
      (lastMoodAt == null ||
          now.difference(lastMoodAt!) <= const Duration(hours: 2));

  /// Everything a cached answer depends on, apart from its age.
  String get cacheKey => [
    account ?? '',
    DayPart.of(now).name,
    '$distressed',
    courseId ?? '',
    courseDay ?? '',
    catalogVersion ?? '',
  ].join('|');

  Map<String, Object?> toJson() => {
    'surface': 'home',
    'localTime': _localTime(now),
    'locale': 'en',
    'catalogVersion': ?catalogVersion,
    'lastMood': ?lastMood,
    'lastMoodAt': ?lastMoodAt?.toUtc().toIso8601String(),
    'opensByKind': opensByKind,
    if (courseId != null && courseDay != null)
      'course': {'id': courseId, 'day': courseDay},
    'limit': 6,
  };

  static String _localTime(DateTime t) {
    String two(int n) => '$n'.padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}'
        'T${two(t.hour)}:${two(t.minute)}';
  }
}

class RecommendationsClient {
  RecommendationsClient._([
    this._client,
    this._baseUrl = recommendationsBaseUrl,
    Future<String?> Function()? token,
  ]) : _token = token ?? _accessToken;

  static final instance = RecommendationsClient._();

  @visibleForTesting
  factory RecommendationsClient.forTest({
    required http.Client client,
    required String baseUrl,
    required Future<String?> Function() token,
  }) => RecommendationsClient._(client, baseUrl, token);

  static Future<String?> _accessToken() async =>
      Supabase.instance.client.auth.currentSession?.accessToken;

  static const timeout = Duration(seconds: 4);
  static const maxAge = Duration(hours: 3);

  /// How old a cached answer may be when the Worker can't be reached.
  static const staleFor = Duration(hours: 24);

  static const _cacheKey = 'discover.recommendations';
  static const _moodKey = 'discover.last_mood';

  final http.Client? _client;
  final String _baseUrl;
  final Future<String?> Function() _token;

  bool get enabled => _baseUrl.isNotEmpty;

  /// Notes a check-in, with its time, for the next request.
  Future<void> noteMood(int index, {DateTime? at}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _moodKey,
        jsonEncode({
          'index': index,
          'at': (at ?? DateTime.now()).toUtc().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('Couldn\'t note the check-in: $e');
    }
  }

  /// The last check-in noted on this device, and when.
  static Future<(int, DateTime)?> lastMood() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_moodKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (json['index'] as int, DateTime.parse(json['at'] as String));
    } catch (_) {
      return null;
    }
  }

  /// The Worker's list for [request], a recent cached one, or null when
  /// Home should use its own order. Never throws.
  Future<List<Recommendation>?> fetch(RecommendationRequest request) async {
    if (!enabled) return null;
    final cached = await _readCache(request);
    if (cached != null && request.now.difference(cached.$1) < maxAge) {
      return cached.$2;
    }
    final fresh = await _call(request);
    if (fresh != null) {
      await _writeCache(request, fresh);
      return fresh;
    }
    if (cached != null && request.now.difference(cached.$1) < staleFor) {
      return cached.$2;
    }
    return null;
  }

  Future<List<Recommendation>?> _call(RecommendationRequest request) async {
    final token = await _token().catchError((_) => null);
    if (token == null) return null;
    final client = _client ?? http.Client();
    try {
      final base = _baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/';
      final res = await client
          .post(
            Uri.parse(base).resolve('v1/recommendations'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(timeout);
      if (res.statusCode != 200) {
        debugPrint('Recommendations: HTTP ${res.statusCode}');
        return null;
      }
      return _parse(jsonDecode(utf8.decode(res.bodyBytes)));
    } catch (e) {
      debugPrint('Recommendations unavailable: $e');
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  static List<Recommendation>? _parse(Object? json) {
    if (json is! Map || json['items'] is! List) return null;
    return [
      for (final x in json['items'] as List)
        if (x is Map && x['id'] is String)
          Recommendation(
            x['id'] as String,
            x['reason'] is String ? x['reason'] as String : '',
          ),
    ];
  }

  Future<(DateTime, List<Recommendation>)?> _readCache(
    RecommendationRequest request,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['key'] != request.cacheKey) return null;
      final items = _parse(json);
      if (items == null) return null;
      return (DateTime.parse(json['at'] as String), items);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(
    RecommendationRequest request,
    List<Recommendation> items,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'key': request.cacheKey,
          'at': request.now.toIso8601String(),
          'items': [
            for (final x in items) {'id': x.id, 'reason': x.reason},
          ],
        }),
      );
    } catch (e) {
      debugPrint('Couldn\'t keep the recommendations: $e');
    }
  }
}

/// [picks] as index items, skipping ids this build doesn't have and
/// [exclude]. Null (use the on-device order) when nothing is left.
List<ContentItem>? itemsForRecommendations(
  List<Recommendation>? picks, {
  Set<String> exclude = const {},
  int count = 5,
  List<ContentItem>? from,
}) {
  if (picks == null) return null;
  final byId = {for (final i in from ?? contentIndex) i.id: i};
  final items = [
    for (final p in picks)
      if (byId[p.id] case final item? when !exclude.contains(item.id)) item,
  ].take(count).toList();
  return items.isEmpty ? null : items;
}
