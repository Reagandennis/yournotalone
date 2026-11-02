import 'dart:io';

import '../content/content_catalog.dart';
import 'media_files.dart';

/// Where a piece of audio will play from.
sealed class AudioOrigin {
  const AudioOrigin();
}

/// Shipped inside the app.
class BundledAudio extends AudioOrigin {
  const BundledAudio(this.asset);

  final String asset;
}

/// Downloaded earlier and checked.
class LocalAudio extends AudioOrigin {
  const LocalAudio(this.file, this.entry);

  final File file;
  final MediaEntry entry;
}

/// Only online, so far.
class RemoteAudio extends AudioOrigin {
  const RemoteAudio(this.entry);

  final MediaEntry entry;
}

/// Picks where audio named by a content path plays from: the app's own
/// copy first, then a download, then the network.
class MediaResolver {
  MediaResolver({
    bool Function(String path)? isBundled,
    MediaEntry? Function(String path)? lookup,
    MediaFiles? files,
  }) : _isBundled = isBundled ?? isBundledAsset,
       _lookup = lookup ?? ContentCatalog.instance.mediaAt,
       _files = files ?? MediaFiles.instance;

  static final instance = MediaResolver();

  final bool Function(String path) _isBundled;
  final MediaEntry? Function(String path) _lookup;
  final MediaFiles _files;

  /// Null when [path] isn't in the app and nothing is published for it.
  Future<AudioOrigin?> resolve(String path) async {
    if (_isBundled(path)) return BundledAudio(path);
    final entry = _lookup(path);
    if (entry == null) return null;
    final file = await _files.downloaded(entry.ref);
    if (file != null) return LocalAudio(file, entry);
    return RemoteAudio(entry);
  }
}
