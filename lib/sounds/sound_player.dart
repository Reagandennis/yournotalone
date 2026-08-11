import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// App-wide ambient sound player: one sound at a time, looping seamlessly,
/// and it keeps playing while the user moves around the app.
///
/// The [AudioPlayer] is created lazily on first play, and in widget tests
/// (FLUTTER_TEST) the service runs silently so state stays testable
/// without platform channels.
class SoundPlayer {
  SoundPlayer._();

  static final SoundPlayer instance = SoundPlayer._();

  static final bool _silent = Platform.environment.containsKey('FLUTTER_TEST');

  AudioPlayer? _player;
  AudioPlayer? _oneShot;
  double _volume = 1.0;

  /// Asset path of the sound currently loaded (playing or paused).
  final ValueNotifier<String?> nowPlaying = ValueNotifier(null);

  /// True when a sound is loaded but paused.
  final ValueNotifier<bool> paused = ValueNotifier(false);

  double get volume => _volume;

  bool isActive(String asset) => nowPlaying.value == asset && !paused.value;

  /// Starts [asset] looping from the beginning.
  Future<void> play(String asset) async {
    nowPlaying.value = asset;
    paused.value = false;
    if (_silent) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.setAsset(asset);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(_volume);
      unawaited(player.play());
    } catch (_) {
      if (nowPlaying.value == asset) {
        nowPlaying.value = null;
        paused.value = false;
      }
      rethrow;
    }
  }

  /// Play/pause from the list row: starts, pauses, or resumes [asset].
  Future<void> toggle(String asset) async {
    if (nowPlaying.value != asset) {
      await play(asset);
    } else if (paused.value) {
      await resume();
    } else {
      await pause();
    }
  }

  Future<void> pause() async {
    paused.value = true;
    if (!_silent) await _player?.pause();
  }

  Future<void> resume() async {
    paused.value = false;
    if (!_silent) unawaited(_player?.play() ?? Future.value());
  }

  Future<void> stop() async {
    nowPlaying.value = null;
    paused.value = false;
    if (!_silent) await _player?.stop();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    if (!_silent) await _player?.setVolume(_volume);
  }

  /// Plays a short one-shot (e.g. the meditation chime) on its own
  /// player, so it can ring over a running ambient loop.
  Future<void> playOnce(String asset) async {
    if (_silent) return;
    try {
      final player = _oneShot ??= AudioPlayer();
      await player.stop();
      await player.setAsset(asset);
      await player.setVolume(_volume);
      unawaited(player.play());
    } catch (e) {
      debugPrint('One-shot playback failed for $asset: $e');
    }
  }
}
