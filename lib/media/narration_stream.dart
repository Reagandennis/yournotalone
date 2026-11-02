// LockCachingAudioSource is marked experimental in just_audio; its API has
// been stable since 0.9 and the design (docs/backend-design.md §6) names it.
// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../content/content_catalog.dart';
import 'media_files.dart';
import 'media_links.dart';

/// A link the voice player can play for [entry]'s narration that isn't in
/// the app or downloaded: its checked stream cache if a whole one exists,
/// else a [LockCachingAudioSource] that streams the file and caches it as
/// `<sha256>.m4a`, so the next listen — even with a fresh signed link — is
/// played from the phone.
///
/// Throws [PremiumRequired] or [MediaUnavailable].
Future<Uri> narrationUrl(
  MediaEntry entry, {
  MediaFiles? files,
  MediaLinks? links,
  NarrationProxy? proxy,
}) async {
  final sha = entry.ref.sha256;
  final cache = await (files ?? MediaFiles.instance).streamCacheFor(sha);
  // A cache left by an earlier stream is checked before it's trusted.
  if (await cache.exists() && await verifyFile(cache, sha)) {
    return Uri.file(cache.path);
  }
  final url = await (links ?? MediaLinks.instance).urlFor(
    entry,
    MediaPurpose.stream,
  );
  await cache.parent.create(recursive: true);
  final source = LockCachingAudioSource(url, cacheFile: cache);
  return (proxy ?? NarrationProxy.instance).serve(sha, source);
}

/// Serves [StreamAudioSource]s over a loopback HTTP port.
///
/// The voice guide plays on audioplayers (just_audio_background allows only
/// one just_audio player, and that's the ambient loop), which can't take a
/// just_audio source directly. This hands it a `http://127.0.0.1` link
/// instead, answering range requests the way just_audio's own proxy does.
class NarrationProxy {
  NarrationProxy();

  static final instance = NarrationProxy();

  Future<HttpServer>? _server;
  final _sources = <String, StreamAudioSource>{};

  /// A local link that plays [source], named [name].
  Future<Uri> serve(String name, StreamAudioSource source) async {
    final server = await (_server ??= _start());
    _sources[name] = source;
    return Uri.http(
      '${InternetAddress.loopbackIPv4.address}:${server.port}',
      '/$name.m4a',
    );
  }

  Future<HttpServer> _start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(
      (request) => unawaited(_handle(request)),
      onError: (Object e) => debugPrint('Narration proxy error: $e'),
    );
    return server;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    final name = request.uri.pathSegments.lastOrNull?.replaceFirst(
      RegExp(r'\.m4a$'),
      '',
    );
    final source = _sources[name];
    if (request.method != 'GET' || source == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
    final range = parseRange(request.headers.value(HttpHeaders.rangeHeader));
    StreamAudioResponse answer;
    try {
      answer = await source.request(range?.$1, range?.$2);
    } catch (e) {
      debugPrint('Narration stream failed: $e');
      response.statusCode = HttpStatus.badGateway;
      await response.close();
      return;
    }
    response.headers.clear();
    response.headers.set(HttpHeaders.contentTypeHeader, answer.contentType);
    if (answer.rangeRequestsSupported) {
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    }
    final length = answer.contentLength;
    if (range != null && answer.offset != null && length != null) {
      final start = answer.offset!;
      response.statusCode = HttpStatus.partialContent;
      response.contentLength = length;
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-${start + length - 1}/${answer.sourceLength ?? '*'}',
      );
    } else {
      response.statusCode = HttpStatus.ok;
      response.contentLength = length ?? -1;
    }
    try {
      await response.addStream(answer.stream);
    } catch (e) {
      // The player hung up mid-answer, as it does when it seeks.
      debugPrint('Narration answer cut short: $e');
    }
    try {
      await response.close();
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> close() async {
    final server = await _server;
    _server = null;
    _sources.clear();
    await server?.close(force: true);
  }
}

/// A `Range: bytes=a-b` header as (start, end exclusive); null if absent
/// or not one this understands.
(int, int?)? parseRange(String? header) {
  if (header == null) return null;
  final match = RegExp(r'^bytes=(\d+)-(\d+)?$').firstMatch(header.trim());
  if (match == null) return null;
  final start = int.parse(match[1]!);
  final end = match[2] == null ? null : int.parse(match[2]!) + 1;
  return (start, end);
}
