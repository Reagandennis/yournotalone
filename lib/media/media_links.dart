import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../content/content_catalog.dart';

/// The Worker that signs links to premium audio (docs/backend-design.md §5).
/// Empty means it isn't set up: free audio still comes straight from the
/// CDN, premium audio that isn't in the app can't be fetched. Staging
/// builds pass the staging Worker with `--dart-define=MEDIA_API_URL=…`.
const mediaApiUrl = String.fromEnvironment(
  'MEDIA_API_URL',
  defaultValue: 'https://yournotalone-api.reaganprezzo.workers.dev',
);

/// Why a link is wanted: the Worker signs streams for longer.
enum MediaPurpose { stream, download }

/// A link to one file, as the Worker returns it.
class SignedMedia {
  const SignedMedia({
    required this.url,
    required this.expires,
    required this.sha256,
    required this.bytes,
  });

  factory SignedMedia.fromJson(Map<String, dynamic> json) => SignedMedia(
    url: Uri.parse(json['url'] as String),
    expires: switch (json['expires']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    sha256: json['sha256'] as String,
    bytes: json['bytes'] as int,
  );

  final Uri url;

  /// Null for public files, whose links don't expire.
  final DateTime? expires;
  final String sha256;
  final int bytes;
}

/// The body of a `POST /v1/media/sign` answer.
class SignResult {
  const SignResult({required this.urls, required this.missing});

  /// Links by item id, then role (`audio`, `narration`).
  final Map<String, Map<String, SignedMedia>> urls;

  /// Requested ids the Worker has no audio for.
  final List<String> missing;
}

/// Reads a sign answer. Roles this build doesn't know are kept; it's the
/// caller that picks the one it wants.
SignResult parseSignResponse(Map<String, dynamic> json) => SignResult(
  urls: {
    for (final MapEntry(key: id, value: roles)
        in (json['urls'] as Map<String, dynamic>).entries)
      id: {
        for (final MapEntry(key: role, value: link)
            in (roles as Map<String, dynamic>).entries)
          role: SignedMedia.fromJson(link as Map<String, dynamic>),
      },
  },
  missing: [...?(json['missing'] as List?)?.cast<String>()],
);

/// The item needs Premium and this account doesn't have it.
class PremiumRequired implements Exception {
  const PremiumRequired();

  @override
  String toString() => 'PremiumRequired';
}

/// The file can't be reached: no Worker set up, signed out, offline, or
/// not published.
class MediaUnavailable implements Exception {
  const MediaUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'MediaUnavailable: $reason';
}

String? _accessToken() {
  try {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  } catch (_) {
    return null; // Supabase not set up (tests, or a failed start).
  }
}

/// Gets a link to a published file: straight to the CDN when it's free,
/// signed by the Worker when it's premium.
class MediaLinks {
  MediaLinks({
    this._client,
    this._apiUrl = mediaApiUrl,
    this._baseUrl = catalogBaseUrl,
    String? Function()? token,
    DateTime Function()? clock,
  }) : _token = token ?? _accessToken,
       _clock = clock ?? DateTime.now;

  static final instance = MediaLinks();

  final http.Client? _client;
  final String _apiUrl;
  final String _baseUrl;
  final String? Function() _token;
  final DateTime Function() _clock;

  /// Signed links still good for a while, by item, role and purpose.
  final _signed = <String, SignedMedia>{};

  /// A signed link is reused until this close to expiring.
  static const _margin = Duration(minutes: 5);

  /// A link to [entry]'s file. Throws [PremiumRequired] or
  /// [MediaUnavailable].
  Future<Uri> urlFor(MediaEntry entry, MediaPurpose purpose) async {
    if (!entry.ref.premium) {
      return Uri.parse(_baseUrl).resolve(entry.ref.key);
    }
    final key = '${entry.itemId}|${entry.role}|${purpose.name}';
    final cached = _signed[key];
    if (cached != null &&
        cached.expires != null &&
        cached.expires!.subtract(_margin).isAfter(_clock())) {
      return cached.url;
    }
    final result = await sign([entry.itemId], purpose);
    final link = result.urls[entry.itemId]?[entry.role];
    if (link == null) throw const MediaUnavailable('not published');
    if (link.sha256 != entry.ref.sha256) {
      // The Worker has a newer catalogue than this phone; this copy's file
      // is gone. The next catalogue will name the new one.
      throw const MediaUnavailable('catalogue out of date');
    }
    _signed[key] = link;
    return link.url;
  }

  /// Asks the Worker for links to [ids]' files.
  Future<SignResult> sign(List<String> ids, MediaPurpose purpose) async {
    if (_apiUrl.isEmpty) throw const MediaUnavailable('no media API');
    final token = _token();
    if (token == null) throw const MediaUnavailable('signed out');
    final client = _client ?? http.Client();
    try {
      final res = await client
          .post(
            Uri.parse(_apiUrl).resolve('v1/media/sign'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'items': ids, 'purpose': purpose.name}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 403) throw const PremiumRequired();
      if (res.statusCode != 200) {
        throw MediaUnavailable('sign failed (${res.statusCode})');
      }
      return parseSignResponse(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    } on PremiumRequired {
      rethrow;
    } on MediaUnavailable {
      rethrow;
    } catch (e) {
      debugPrint('Media sign failed: $e');
      throw MediaUnavailable('$e');
    } finally {
      if (_client == null) client.close();
    }
  }
}
