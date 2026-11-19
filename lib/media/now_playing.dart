import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// What the lock screen's and the notification's buttons control: the
/// sound or the meditation that is showing there.
abstract interface class NowPlayingSession {
  Future<void> play();
  Future<void> pause();

  /// Stop was pressed, or the notification was swiped away: end it.
  Future<void> stop();
}

/// The app's one media session — the lock screen, the notification, the
/// Control Centre, headphone buttons.
///
/// It shows one thing at a time: a sound playing on its own, or a
/// meditation (with whatever sound runs under it). Whoever [show]s takes
/// it over; the buttons go to that owner's [NowPlayingSession], and only
/// that owner can [update] or [release] it, so a sound stopping under a
/// meditation can't clear the meditation off the lock screen.
///
/// It also handles what interrupts audio — a phone call, another app,
/// headphones coming out — for whichever owner is showing, so the app's own
/// play buttons always agree with what is heard.
class NowPlaying extends BaseAudioHandler {
  @visibleForTesting
  NowPlaying();

  /// The live session after [init]; before that, or when the platform has
  /// none, a stand-in that keeps the same state and shows it nowhere.
  static NowPlaying instance = NowPlaying();

  /// Whether the platform session started (see [init]).
  static bool ready = false;

  /// Starts the platform media session. Never fatal: a hot restart after
  /// adding the plugin, or a platform without one, throws here, and the
  /// app failing to launch over a lock-screen player would be far worse
  /// than playing in the foreground only.
  static Future<void> init() async {
    try {
      instance = await AudioService.init(
        builder: NowPlaying.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.techgetafrica.yournotalone.audio',
          androidNotificationChannelName: 'Wellbeing sounds',
          // Swipeable once paused: a paused sound or meditation shouldn't
          // pin a notification nobody can dismiss.
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
        ),
      );
      ready = true;
    } catch (error) {
      debugPrint('Background audio unavailable, playing in foreground: $error');
      rethrow;
    } finally {
      // The stand-in still tracks interruptions, so the play buttons keep
      // working the same way.
      unawaited(instance._watchAudioSession());
    }
  }

  Object? _owner;
  NowPlayingSession? _session;

  /// Set when an interruption paused the owner, so its end can resume it.
  bool _pausedByInterruption = false;

  /// Who is showing, if anyone.
  Object? get owner => _owner;

  /// Puts [item] on the lock screen, controlled by [session], in place of
  /// whatever was there. Follow with [update] to say whether it plays.
  void show(Object owner, MediaItem item, NowPlayingSession session) {
    _owner = owner;
    _session = session;
    _pausedByInterruption = false;
    mediaItem.add(item);
  }

  /// New details for what [owner] is showing, e.g. once its picture is
  /// drawn. Ignored if someone else has taken over since.
  void updateItem(Object owner, MediaItem item) {
    if (owner != _owner) return;
    mediaItem.add(item);
  }

  /// Whether [owner]'s item plays. [position] is how far in it is, for an
  /// item with a duration; the lock screen moves it on by itself while it
  /// plays.
  void update(
    Object owner, {
    required bool playing,
    bool loading = false,
    Duration position = Duration.zero,
  }) {
    if (owner != _owner) return;
    final wasPlaying = playbackState.value.playing;
    if (playing) _pausedByInterruption = false;
    playbackState.add(
      PlaybackState(
        processingState: loading
            ? AudioProcessingState.loading
            : AudioProcessingState.ready,
        playing: playing,
        controls: [
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1],
        // No seeking: a meditation's clock and a looping sound have nothing
        // to seek to.
        systemActions: const {},
        updatePosition: position,
        speed: 1,
      ),
    );
    // Holding audio focus is what makes other apps go quiet, and what
    // tells the system to send this app the interruptions.
    if (playing && !wasPlaying) unawaited(_activate());
  }

  /// [owner] is done: the lock screen and the notification clear.
  void release(Object owner) {
    if (owner != _owner) return;
    _owner = null;
    _session = null;
    _pausedByInterruption = false;
    playbackState.add(PlaybackState());
  }

  // ── The buttons ──────────────────────────────────────────────────────

  @override
  Future<void> play() async {
    _pausedByInterruption = false;
    await _session?.play();
  }

  @override
  Future<void> pause() async {
    _pausedByInterruption = false;
    await _session?.pause();
  }

  @override
  Future<void> stop() async {
    final session = _session;
    if (session == null) {
      playbackState.add(PlaybackState());
      return;
    }
    await session.stop();
  }

  @override
  Future<void> onNotificationDeleted() => stop();

  /// The app was swiped away on Android: nothing should keep playing.
  @override
  Future<void> onTaskRemoved() => stop();

  // ── Interruptions ────────────────────────────────────────────────────

  StreamSubscription<AudioInterruptionEvent>? _interruptions;
  StreamSubscription<void>? _noisy;
  Future<AudioSession>? _audioSession;

  Future<void> _watchAudioSession() async {
    if (_audioSession != null) return;
    try {
      final session = _audioSession = AudioSession.instance;
      final s = await session;
      await s.configure(const AudioSessionConfiguration.music());
      _interruptions = s.interruptionEventStream.listen(interrupted);
      _noisy = s.becomingNoisyEventStream.listen((_) => becameNoisy());
    } catch (e) {
      debugPrint('Audio session unavailable: $e');
    }
  }

  Future<void> _activate() async {
    final session = _audioSession;
    if (session == null) return;
    try {
      await (await session).setActive(true);
    } catch (e) {
      debugPrint('Audio session activation failed: $e');
    }
  }

  /// A call, an alarm or another app took the audio. A short interruption
  /// pauses and resumes; losing it for good only pauses.
  @visibleForTesting
  void interrupted(AudioInterruptionEvent event) {
    final session = _session;
    if (session == null) return;
    if (event.begin) {
      switch (event.type) {
        case AudioInterruptionType.duck:
          // A navigation prompt over a sleep sound: carry on.
          return;
        case AudioInterruptionType.pause:
        case AudioInterruptionType.unknown:
          if (!playbackState.value.playing) return;
          unawaited(session.pause());
          // Set after, as the owner's own update clears it.
          _pausedByInterruption = event.type == AudioInterruptionType.pause;
      }
    } else if (_pausedByInterruption) {
      _pausedByInterruption = false;
      if (event.type == AudioInterruptionType.pause) {
        unawaited(session.play());
      }
    }
  }

  /// Headphones came out: pause rather than play out loud.
  @visibleForTesting
  void becameNoisy() {
    _pausedByInterruption = false;
    if (playbackState.value.playing) unawaited(_session?.pause());
  }

  @visibleForTesting
  Future<void> dispose() async {
    await _interruptions?.cancel();
    await _noisy?.cancel();
  }
}
