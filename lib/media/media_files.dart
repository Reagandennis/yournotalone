import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../content/catalog_snapshot.dart';

/// Where fetched audio lives on the phone (docs/backend-design.md §6).
///
/// Downloads go in the app support directory, which the system leaves
/// alone; streamed narration is cached in the cache directory, which it
/// may clear when space runs low. Both are named after the file's sha256,
/// so a fresh signed link still finds the same copy.
class MediaFiles {
  MediaFiles({
    Future<Directory> Function()? support,
    Future<Directory> Function()? cache,
  }) : _support = support ?? getApplicationSupportDirectory,
       _cache = cache ?? getApplicationCacheDirectory;

  static final instance = MediaFiles();

  /// The folder downloads go in, under the app support directory. The
  /// background downloader is told the same.
  static const folder = 'media';

  final Future<Directory> Function() _support;
  final Future<Directory> Function() _cache;

  Future<Directory> get downloadsDir async =>
      Directory('${(await _support()).path}/$folder');

  /// Where [sha256]'s download is kept once checked.
  Future<File> downloadFor(String sha256) async =>
      File('${(await downloadsDir).path}/$sha256.m4a');

  /// Where [sha256]'s download is written until it's checked.
  Future<File> partFor(String sha256) async =>
      File('${(await downloadsDir).path}/$sha256.m4a.part');

  /// Where streamed narration for [sha256] is cached.
  Future<File> streamCacheFor(String sha256) async =>
      File('${(await _cache()).path}/narration/$sha256.m4a');

  /// [ref]'s downloaded copy, or null if there isn't a whole one.
  Future<File?> downloaded(MediaRef ref) async {
    final file = await downloadFor(ref.sha256);
    if (!await file.exists()) return null;
    return await file.length() == ref.bytes ? file : null;
  }
}

/// The sha256 of [file]'s contents, as lower-case hex.
Future<String> sha256OfFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

/// Whether [file] is exactly the file [expected] names. A file that isn't
/// is deleted, so a damaged download is never played.
Future<bool> verifyFile(File file, String expected) async {
  try {
    if (await sha256OfFile(file) == expected.toLowerCase()) return true;
    debugPrint('${file.path} failed its checksum; deleting it.');
  } catch (e) {
    debugPrint('Couldn\'t check ${file.path}: $e');
  }
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {}
  return false;
}
