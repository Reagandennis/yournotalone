// Fakes for the audio engines behind SoundPlayer, so playback can be
// followed in tests without platform channels. Not a test itself.
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart' as sfx;

import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/media/download_store.dart';
import 'package:yournotalone/media/media_source.dart';
import 'package:yournotalone/media/now_playing.dart';
import 'package:yournotalone/sounds/sound_player.dart';

/// Records what the ambient loop was told to do.
class FakeLoop implements LoopEngine {
  final log = <String>[];
  final _errors = StreamController<Object>.broadcast();
  bool playing = false;
  String? loaded;

  /// Fails the next load with this, if set.
  Object? failLoad;

  /// Holds the next load until completed, if set.
  Completer<void>? holdLoad;

  @override
  Stream<Object> get errors => _errors.stream;

  void breakPlayback(Object error) => _errors.add(error);

  @override
  Future<void> load({String? asset, String? file}) async {
    final hold = holdLoad;
    holdLoad = null;
    if (hold != null) await hold.future;
    final failure = failLoad;
    if (failure != null) {
      failLoad = null;
      throw failure;
    }
    loaded = file ?? asset;
    log.add('load ${file ?? asset}');
  }

  @override
  Future<void> play() async {
    playing = true;
    log.add('play');
  }

  @override
  Future<void> pause() async {
    playing = false;
    log.add('pause');
  }

  @override
  Future<void> stop() async {
    playing = false;
    log.add('stop');
  }

  @override
  Future<void> setVolume(double volume) async {}
}

/// Records what the voice guide was told to do.
class FakeVoice implements VoiceEngine {
  final log = <String>[];

  @override
  Future<void> start(sfx.Source source, Duration from) async {
    final name = switch (source) {
      sfx.AssetSource(:final path) => path,
      sfx.DeviceFileSource(:final path) => path,
      sfx.UrlSource(:final url) => url,
      _ => '$source',
    };
    log.add('start $name at ${from.inSeconds}s');
  }

  @override
  Future<void> pause() async => log.add('pause');

  @override
  Future<void> resume() async => log.add('resume');

  @override
  Future<void> seek(Duration to) async => log.add('seek ${to.inSeconds}s');

  @override
  Future<void> stop() async => log.add('stop');
}

/// A sound published online only, which has to be downloaded first.
MediaEntry remoteEntry(String path, {String title = 'Rainfall'}) => MediaEntry(
  itemId: 'sound:$title',
  title: title,
  role: 'audio',
  path: path,
  ref: const MediaRef(key: 'k', sha256: 'abc', bytes: 1, premium: false),
);

/// Puts SoundPlayer back the way the app runs it in tests: silent, with
/// the real resolver and download.
void resetSoundPlayer() {
  final player = SoundPlayer.instance
    ..loopEngine = null
    ..voiceEngine = null;
  player.resolve = (path) => MediaResolver.instance.resolve(path);
  player.fetch = (entry) => DownloadStore.instance.fetchNow(entry);
}

/// A fresh, platform-free lock screen for each test.
NowPlaying freshNowPlaying() => NowPlaying.instance = NowPlaying();

/// What the lock screen shows right now.
MediaItem? get shownItem => NowPlaying.instance.mediaItem.value;
PlaybackState get shownState => NowPlaying.instance.playbackState.value;

/// A stand-in file for a finished download.
File downloadedFile(String name) => File('/tmp/$name');
