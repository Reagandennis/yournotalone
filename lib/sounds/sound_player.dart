import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../practice/practice_repository.dart';
import 'sounds_catalog.dart';

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

  /// When the current sound started playing, so a real listen can be told
  /// from a two-second sample.
  DateTime? _startedAt;

  /// Listening only counts once it has run this long.
  static const _minLoggedMinutes = 3.0;

  /// Overridable for tests.
  PracticeRepository practice = PracticeRepository();

  /// Counts down to stopping the sound, or null when nothing is set.
  final ValueNotifier<Duration?> sleepTimer = ValueNotifier(null);
  Timer? _sleepTimerHandle;
  DateTime? _sleepAt;

  /// Stops the sound after [duration], fading out over the last seconds so
  /// it doesn't cut off in someone's ear. Pass null to cancel.
  void setSleepTimer(Duration? duration) {
    _sleepTimerHandle?.cancel();
    if (duration == null) {
      _sleepAt = null;
      sleepTimer.value = null;
      return;
    }
    _sleepAt = DateTime.now().add(duration);
    sleepTimer.value = duration;
    _sleepTimerHandle =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      final left = _sleepAt?.difference(DateTime.now()) ?? Duration.zero;
      if (left <= Duration.zero) {
        timer.cancel();
        await _fadeOutAndStop();
        return;
      }
      sleepTimer.value = left;
      // Fade over the last 20 seconds.
      if (left.inSeconds <= 20 && !_silent) {
        await _player?.setVolume(_volume * (left.inSeconds / 20));
      }
    });
  }

  Future<void> _fadeOutAndStop() async {
    _sleepAt = null;
    sleepTimer.value = null;
    await stop();
    if (!_silent) await _player?.setVolume(_volume);
  }

  /// Records the listen that just ended, if it lasted long enough to mean
  /// anything. Called on stop, on pause, and when switching sounds.
  Future<void> _logElapsed() async {
    final started = _startedAt;
    final asset = nowPlaying.value;
    _startedAt = null;
    if (started == null || asset == null) return;
    final minutes =
        DateTime.now().difference(started).inSeconds / 60;
    if (minutes < _minLoggedMinutes) return;
    final matches = soundsCatalog.where((s) => s.asset == asset);
    if (matches.isEmpty) return;
    final sound = matches.first;
    await practice.logSession(
      kind: PracticeKind.sound,
      slug: sound.title,
      title: sound.title,
      minutes: minutes,
    );
  }

  /// Asset path of the sound currently loaded (playing or paused).
  final ValueNotifier<String?> nowPlaying = ValueNotifier(null);

  /// True when a sound is loaded but paused.
  final ValueNotifier<bool> paused = ValueNotifier(false);

  double get volume => _volume;

  bool isActive(String asset) => nowPlaying.value == asset && !paused.value;

  /// Starts [asset] looping from the beginning.
  Future<void> play(String asset) async {
    await _logElapsed(); // whatever was playing before
    nowPlaying.value = asset;
    paused.value = false;
    _startedAt = DateTime.now();
    if (_silent) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      final matches = soundsCatalog.where((s) => s.asset == asset);
      final title = matches.isEmpty ? 'Wellbeing sound' : matches.first.title;
      await player.setAudioSource(
        AudioSource.asset(
          asset,
          // What the lock screen and notification show while it plays.
          tag: MediaItem(
            id: asset,
            title: title,
            artist: 'Δεν είσαι μόνος',
          ),
        ),
      );
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
    await _logElapsed();
    paused.value = true;
    if (!_silent) await _player?.pause();
  }

  Future<void> resume() async {
    paused.value = false;
    _startedAt = DateTime.now();
    if (!_silent) unawaited(_player?.play() ?? Future.value());
  }

  Future<void> stop() async {
    await _logElapsed();
    _sleepTimerHandle?.cancel();
    _sleepAt = null;
    sleepTimer.value = null;
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
