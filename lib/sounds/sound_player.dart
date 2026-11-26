import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart' as sfx;
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../content/content_catalog.dart';
import '../discover/content_index.dart';
import '../l10n/l10n.dart';
import '../media/cover_art.dart';
import '../media/download_store.dart';
import '../media/media_source.dart';
import '../media/narration_stream.dart';
import '../media/now_playing.dart';
import '../practice/practice_repository.dart';
import 'sounds_catalog.dart';

/// The ambient loop's engine: just_audio in the app, a fake in tests.
abstract interface class LoopEngine {
  /// Loads [file] (a path on the phone) or else [asset] (in the app), to
  /// loop seamlessly. Doesn't start it.
  Future<void> load({String? asset, String? file});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double volume);

  /// Playback that failed after it started, e.g. a damaged file.
  Stream<Object> get errors;
}

/// The voice guide's engine: audioplayers in the app, a fake in tests.
abstract interface class VoiceEngine {
  /// Plays [source] from [from].
  Future<void> start(sfx.Source source, Duration from);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration to);
  Future<void> stop();
}

/// Chimes and the voice don't ask for audio focus of their own: the
/// session ([NowPlaying]) holds it for the whole sound or meditation, and
/// on Android a chime asking for focus paused the app's own ambient loop.
/// iOS keeps `playback` without mixing, or the app drops off the lock
/// screen.
final _overTheLoop = sfx.AudioContext(
  android: const sfx.AudioContextAndroid(
    audioFocus: sfx.AndroidAudioFocus.none,
    usageType: sfx.AndroidUsageType.media,
    contentType: sfx.AndroidContentType.music,
  ),
  iOS: sfx.AudioContextIOS(category: sfx.AVAudioSessionCategory.playback),
);

class _JustAudioLoop implements LoopEngine {
  // Interruptions are [NowPlaying]'s to handle, for the sound and the
  // meditation alike, so the play buttons hear about them.
  final _player = AudioPlayer(handleInterruptions: false);
  final _errors = StreamController<Object>.broadcast();

  _JustAudioLoop() {
    _player.playbackEventStream.listen(
      null,
      onError: (Object e, StackTrace _) => _errors.add(e),
    );
  }

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> load({String? asset, String? file}) async {
    await _player.setAudioSource(
      file != null ? AudioSource.file(file) : AudioSource.asset(asset!),
    );
    await _player.setLoopMode(LoopMode.one);
  }

  // just_audio's play() finishes only when playback stops.
  @override
  Future<void> play() async => unawaited(_player.play());

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);
}

class _AudioplayersVoice implements VoiceEngine {
  final _player = sfx.AudioPlayer();
  late final Future<void> _ready = _player.setAudioContext(_overTheLoop);

  @override
  Future<void> start(sfx.Source source, Duration from) async {
    await _ready;
    await _player.stop();
    await _player.play(source, position: from > Duration.zero ? from : null);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> seek(Duration to) => _player.seek(to);

  @override
  Future<void> stop() => _player.stop();
}

/// App-wide ambient sound player: one sound at a time, looping seamlessly,
/// and it keeps playing while the user moves around the app.
///
/// A sound playing on its own is what the lock screen shows ([NowPlaying]);
/// one playing under a meditation leaves the lock screen to the meditation.
///
/// The engines are created on first use, and in widget tests (FLUTTER_TEST)
/// there are none unless a test hands in fakes, so state stays testable
/// without platform channels.
class SoundPlayer {
  SoundPlayer._();

  static final SoundPlayer instance = SoundPlayer._();

  static final bool _silent = Platform.environment.containsKey('FLUTTER_TEST');

  LoopEngine? _loopEngine;
  StreamSubscription<Object>? _loopErrors;

  LoopEngine? get _loop {
    final engine = _loopEngine ??= _silent ? null : _JustAudioLoop();
    if (engine != null) _loopErrors ??= engine.errors.listen(_failed);
    return engine;
  }

  /// Hands in a fake loop engine (null: silent again).
  @visibleForTesting
  set loopEngine(LoopEngine? engine) {
    _loopErrors?.cancel();
    _loopErrors = null;
    _loopEngine = engine;
  }

  VoiceEngine? _voiceEngine;
  VoiceEngine? get _voice =>
      _voiceEngine ??= _silent ? null : _AudioplayersVoice();

  @visibleForTesting
  set voiceEngine(VoiceEngine? engine) => _voiceEngine = engine;

  /// Where a content path plays from; overridable for tests.
  @visibleForTesting
  Future<AudioOrigin?> Function(String path) resolve = (path) =>
      MediaResolver.instance.resolve(path);

  /// Downloads a sound that isn't on the phone yet; overridable for tests.
  @visibleForTesting
  Future<File> Function(MediaEntry entry) fetch = (entry) =>
      DownloadStore.instance.fetchNow(entry);

  /// Chimes run on their own engine, so one can ring over the ambient loop
  /// and the voice.
  sfx.AudioPlayer? _oneShot;
  Future<void>? _oneShotReady;

  double _volume = 1.0;

  /// When the current sound started playing, so a real listen can be told
  /// from a two-second sample.
  DateTime? _startedAt;

  /// Who was signed in when the current listen began.
  String? _startedBy;

  /// The account signed in now; overridable for tests.
  @visibleForTesting
  String? Function() userId = _signedInUserId;

  static String? _signedInUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null; // Supabase not set up (tests, or a failed start).
    }
  }

  /// Listening only counts once it has run this long.
  static const _minLoggedMinutes = 3.0;

  /// Overridable for tests.
  PracticeRepository practice = PracticeRepository();

  /// Overridable for tests, so a listen can be made long enough to count.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// Counts up with every [play] and [stop]: a call that finds a higher
  /// number after waiting has been overtaken, and stops there.
  int _request = 0;

  /// Whether the current sound has loaded and can start at once.
  bool _ready = false;

  /// Whether the current sound plays under a meditation, which then owns
  /// the lock screen.
  bool _underneath = false;

  /// The sound whose details the lock screen has.
  String? _shown;

  /// Names of sounds played from a download, for the lock screen.
  final _titles = <String, String>{};

  late final _session = _SoundSession(this);

  /// Counts down to stopping the sound, or null when nothing is set.
  final ValueNotifier<Duration?> sleepTimer = ValueNotifier(null);
  Timer? _sleepTimerHandle;
  DateTime? _sleepAt;

  /// Stops the sound after [duration], fading out over the last seconds so
  /// it doesn't cut off in someone's ear. Pass null to cancel.
  void setSleepTimer(Duration? duration) {
    _sleepTimerHandle?.cancel();
    _sleepTimerHandle = null;
    // Cancelled or changed during the fade: back to full volume, or the
    // sound carries on at whatever the fade had got down to.
    _endFade();
    if (duration == null) {
      _sleepAt = null;
      sleepTimer.value = null;
      return;
    }
    _sleepAt = clock().add(duration);
    sleepTimer.value = duration;
    _sleepTimerHandle = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      final left = _sleepAt?.difference(clock()) ?? Duration.zero;
      if (left <= Duration.zero) {
        timer.cancel();
        await _fadeOutAndStop();
        return;
      }
      sleepTimer.value = left;
      // Fade over the last 20 seconds.
      if (left.inSeconds <= 20) {
        _fading = true;
        await _loop?.setVolume(_volume * (left.inSeconds / 20));
      }
    });
  }

  /// Whether the sleep timer has turned the sound down.
  bool _fading = false;

  void _endFade() {
    if (!_fading) return;
    _fading = false;
    unawaited(_loop?.setVolume(_volume));
  }

  Future<void> _fadeOutAndStop() async {
    _sleepAt = null;
    sleepTimer.value = null;
    await stop();
    _fading = false;
    await _loop?.setVolume(_volume);
  }

  /// Records the listen that just ended, if it lasted long enough to mean
  /// anything. Called on stop, on pause, and when switching sounds.
  ///
  /// The write is not awaited: the button that called this is waiting on
  /// the audio, and a network write on a poor connection used to hold the
  /// pause or stop for as long as the request took. The repository swallows
  /// and times out its own failures.
  void _logElapsed() {
    final started = _startedAt;
    final asset = nowPlaying.value;
    final by = _startedBy;
    _startedAt = null;
    _startedBy = null;
    if (started == null || asset == null) return;
    // Listened to by someone who has since signed out (or been replaced
    // by someone else signing in): it isn't the account here now's.
    if (by != userId()) return;
    final minutes = clock().difference(started).inSeconds / 60;
    if (minutes < _minLoggedMinutes) return;
    final sound = _soundAt(asset);
    if (sound == null) return;
    unawaited(
      practice.logSession(
        kind: PracticeKind.sound,
        slug: practiceSlug(sound.id),
        title: sound.title,
        minutes: minutes,
      ),
    );
  }

  /// Asset path of the sound currently loaded (playing or paused).
  final ValueNotifier<String?> nowPlaying = ValueNotifier(null);

  /// True when a sound is loaded but paused.
  final ValueNotifier<bool> paused = ValueNotifier(false);

  /// The sound being fetched before it can play, if any. A loop that isn't
  /// in the app is downloaded whole first, so it can loop without a gap.
  final ValueNotifier<String?> preparing = ValueNotifier(null);

  double get volume => _volume;

  bool isActive(String asset) => nowPlaying.value == asset && !paused.value;

  static Sound? _soundAt(String asset) {
    for (final s in soundLibrary) {
      if (s.asset == asset) return s;
    }
    return null;
  }

  /// Starts [asset] looping from the beginning. [asset] is the content
  /// path that names the sound; one that isn't in the app is played from
  /// its download, fetching it first if need be.
  ///
  /// [underneath] plays it under a meditation, which keeps the lock screen.
  ///
  /// Throws [PremiumRequired] or [MediaUnavailable] when it can't be
  /// fetched, unless another sound or a stop came first.
  Future<void> play(String asset, {bool underneath = false}) async {
    _logElapsed(); // whatever was playing before
    final request = ++_request;
    nowPlaying.value = asset;
    paused.value = false;
    _ready = false;
    _underneath = underneath;
    _startedAt = clock();
    _startedBy = userId();
    final engine = _loop;
    if (engine == null) {
      _publish();
      return;
    }
    _publish(loading: true);
    try {
      await engine.stop();
      if (request != _request) return;
      final origin = await resolve(asset);
      if (request != _request) return;
      String? file;
      switch (origin) {
        case BundledAudio() || null:
          _holdLoop(null);
        case LocalAudio(file: final f, :final entry):
          file = f.path;
          _titles[asset] = entry.title;
          _holdLoop(entry.ref.sha256);
        case RemoteAudio(:final entry):
          _titles[asset] = entry.title;
          preparing.value = asset;
          _publish(loading: true);
          try {
            file = (await fetch(entry)).path;
          } finally {
            if (preparing.value == asset) preparing.value = null;
          }
          // Another sound was chosen, or this one stopped, while it came.
          if (request != _request) return;
          _holdLoop(entry.ref.sha256);
      }
      await engine.load(asset: file == null ? asset : null, file: file);
      await engine.setVolume(_volume);
      if (request != _request) return;
      _ready = true;
      // Paused while it was being fetched: it waits for resume().
      if (!paused.value) await engine.play();
      _publish();
    } catch (_) {
      // Overtaken: the load was cut short on purpose, not a failure.
      if (request != _request) return;
      nowPlaying.value = null;
      paused.value = false;
      _ready = false;
      _holdLoop(null);
      _publish();
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

  /// Pauses the sound; one still being fetched stays paused when it's in.
  Future<void> pause() async {
    if (nowPlaying.value == null) return;
    _logElapsed();
    paused.value = true;
    _publish();
    if (_ready) await _loop?.pause();
  }

  Future<void> resume() async {
    if (nowPlaying.value == null) return;
    paused.value = false;
    _startedAt = clock();
    _startedBy = userId();
    _publish();
    if (_ready) await _loop?.play();
  }

  Future<void> stop() async {
    _logElapsed();
    _request++;
    _ready = false;
    _sleepTimerHandle?.cancel();
    _sleepAt = null;
    sleepTimer.value = null;
    nowPlaying.value = null;
    paused.value = false;
    if (preparing.value != null) preparing.value = null;
    _publish();
    await _loop?.stop();
    _holdLoop(null);
    // Stopped during the sleep timer's fade: the next sound starts at full
    // volume. After the stop, so the end of the fade doesn't blare.
    if (_fading) {
      _fading = false;
      await _loop?.setVolume(_volume);
    }
  }

  /// A meditation takes over the sound already playing: it carries on
  /// under the meditation, which owns the lock screen from now on.
  void playUnderneath() => _underneath = true;

  /// Playback broke after it started (e.g. a damaged download): say so
  /// rather than show a pause button over silence.
  void _failed(Object error) {
    debugPrint('Sound playback failed: $error');
    // A load cut short by the next sound reports here too; only playback
    // that had started counts.
    if (!_ready || nowPlaying.value == null) return;
    _request++;
    _ready = false;
    nowPlaying.value = null;
    paused.value = false;
    _holdLoop(null);
    _publish();
  }

  // ── Downloaded files in use ──────────────────────────────────────────

  /// The downloaded files (by sha256) the loop and the voice have open,
  /// so removing their download doesn't delete them mid-play: the store
  /// deletes them once they're let go.
  String? _loopHeld;
  String? _voiceHeld;

  void _holdLoop(String? sha) {
    final old = _loopHeld;
    if (old == sha) return;
    _loopHeld = sha;
    if (sha != null) DownloadStore.instance.hold(sha);
    if (old != null) unawaited(DownloadStore.instance.release(old));
  }

  void _holdVoice(String? sha) {
    final old = _voiceHeld;
    if (old == sha) return;
    _voiceHeld = sha;
    if (sha != null) DownloadStore.instance.hold(sha);
    if (old != null) unawaited(DownloadStore.instance.release(old));
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await _loop?.setVolume(_volume);
  }

  // ── The lock screen ──────────────────────────────────────────────────

  /// Tells [NowPlaying] what plays, unless a meditation has it.
  void _publish({bool loading = false}) {
    final asset = nowPlaying.value;
    final lockScreen = NowPlaying.instance;
    if (asset == null) {
      _shown = null;
      lockScreen.release(this);
      return;
    }
    if (_underneath) return;
    if (lockScreen.owner != this || _shown != asset) {
      _shown = asset;
      final sound = _soundAt(asset);
      lockScreen.show(this, _itemFor(asset, sound), _session);
      if (sound != null) unawaited(_addArt(asset, sound));
    }
    lockScreen.update(
      this,
      playing: !paused.value,
      loading: loading || preparing.value == asset,
    );
  }

  MediaItem _itemFor(String asset, Sound? sound, [Uri? art]) {
    final l10n = currentL10n();
    return MediaItem(
      id: sound?.id ?? asset,
      title: sound?.title ?? _titles[asset] ?? l10n.soundPlayerFallbackTitle,
      artist: sound?.detail,
      album: sound == null
          ? l10n.soundPlayerFallbackTitle
          : l10n.nowPlayingSound(sound.category.label),
      displayDescription: sound?.detail,
      artUri: art,
    );
  }

  Future<void> _addArt(String asset, Sound sound) async {
    final art = await CoverArt.forItem(
      itemId: sound.id,
      kind: ContentKind.sound,
      icon: sound.icon,
      accent: sound.category.accent,
    );
    if (art == null || _shown != asset) return;
    NowPlaying.instance.updateItem(this, _itemFor(asset, sound, art));
  }

  // ── Chimes ───────────────────────────────────────────────────────────

  /// Plays a short one-shot (e.g. the meditation chime) on its own
  /// player, so it can ring over a running ambient loop.
  Future<void> playOnce(String asset) async {
    if (_silent) return;
    try {
      final player = _oneShot ??= sfx.AudioPlayer();
      await (_oneShotReady ??= player.setAudioContext(_overTheLoop));
      await player.stop();
      await player.setVolume(_volume);
      // audioplayers resolves asset paths relative to assets/.
      await player.play(sfx.AssetSource(asset.replaceFirst('assets/', '')));
    } catch (e) {
      debugPrint('One-shot playback failed for $asset: $e');
    }
  }

  // ── The voice guide ──────────────────────────────────────────────────

  /// Counts up with every start and stop of the voice, like [_request].
  int _voiceRequest = 0;

  /// The recording the voice player has loaded, once it has started.
  String? _voiceLoaded;

  /// Starts a meditation's recorded voice guide [from] a point in it: from
  /// the app, a download, or streamed (and cached) when it's neither.
  Future<void> narrate(String asset, {Duration from = Duration.zero}) async {
    final request = ++_voiceRequest;
    _voiceLoaded = null;
    final engine = _voice;
    if (engine == null) return;
    try {
      final origin = await resolve(asset);
      if (request != _voiceRequest) return;
      _holdVoice(origin is LocalAudio ? origin.entry.ref.sha256 : null);
      final sfx.Source source = switch (origin) {
        BundledAudio() ||
        null => sfx.AssetSource(asset.replaceFirst('assets/', '')),
        LocalAudio(:final file) => sfx.DeviceFileSource(file.path),
        RemoteAudio(:final entry) => switch (await narrationUrl(entry)) {
          final url when url.isScheme('file') => sfx.DeviceFileSource(
            url.toFilePath(),
          ),
          final url => sfx.UrlSource(url.toString()),
        },
      };
      // Paused, turned off or left while the link was fetched.
      if (request != _voiceRequest) return;
      await engine.start(source, from);
      if (request != _voiceRequest) {
        await engine.stop();
        return;
      }
      _voiceLoaded = asset;
    } catch (e) {
      debugPrint('Voice guide failed for $asset: $e');
    }
  }

  /// Pauses the voice; one still starting won't.
  Future<void> pauseNarration() async {
    _voiceRequest++;
    try {
      if (_voiceLoaded != null) await _voice?.pause();
    } catch (e) {
      debugPrint('Voice guide pause failed: $e');
    }
  }

  /// Carries on with [asset]'s voice [at] the session's point, so it stays
  /// in step with the clock: where it is, if it's loaded, else from there.
  Future<void> resumeNarration(String asset, {required Duration at}) async {
    if (_voiceLoaded != asset) return narrate(asset, from: at);
    final request = ++_voiceRequest;
    try {
      await _voice?.seek(at);
      if (request != _voiceRequest) return;
      await _voice?.resume();
    } catch (e) {
      debugPrint('Voice guide resume failed: $e');
    }
  }

  Future<void> stopNarration() async {
    _voiceRequest++;
    _voiceLoaded = null;
    try {
      await _voice?.stop();
    } catch (e) {
      debugPrint('Voice guide stop failed: $e');
    }
    _holdVoice(null);
  }
}

/// The lock screen's buttons, for a sound playing on its own.
class _SoundSession implements NowPlayingSession {
  _SoundSession(this._player);

  final SoundPlayer _player;

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();
}
