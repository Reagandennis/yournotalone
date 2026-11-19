import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../billing/pricing_copy.dart';

import '../auth/auth_ui.dart';
import '../backgrounds/background_picker.dart';
import '../backgrounds/scene_background.dart';
import '../brand.dart';
import '../brand_layout.dart';
import '../content/content_catalog.dart';
import '../discover/content_index.dart';
import '../home/home_ui.dart';
import '../media/cover_art.dart';
import '../media/download_buttons.dart';
import '../media/download_store.dart';
import '../media/download_strings.dart';
import '../media/media_links.dart';
import '../media/now_playing.dart';
import '../l10n/l10n.dart';
import '../practice/practice_repository.dart';
import '../practice/session_close_out.dart';
import '../sounds/sound_player.dart';
import '../sounds/sounds_catalog.dart';
import 'meditation_catalog.dart';
import 'session_clock.dart';
import 'session_end_notice.dart';

/// A timed meditation: progress ring, gentle prompts that change as the
/// session unfolds, optional ambient sound underneath, chime at both ends.
class MeditationScreen extends StatefulWidget {
  const MeditationScreen({super.key, required this.meditation, this.practice});

  /// Injectable so the logging can be verified without a backend.
  final PracticeRepository? practice;

  final Meditation meditation;

  @override
  State<MeditationScreen> createState() => _MeditationScreenState();
}

class _MeditationScreenState extends State<MeditationScreen>
    with WidgetsBindingObserver
    implements NowPlayingSession {
  /// The session's time, by the wall clock: it keeps going while the
  /// phone is locked (see [SessionClock]).
  late final SessionClock _clock = SessionClock(
    Duration(minutes: meditation.minutes),
    onDone: _finish,
  );
  bool _done = false;
  String? _ambient; // asset of the background sound, chosen or carried on

  /// Whether the recorded voice guide plays, when the session has one.
  bool _voice = true;
  bool get _hasVoice => meditation.narration != null;

  /// Whether the app is out of sight (the phone locked, another app open).
  bool _inBackground = false;

  /// The lock screen's second line, read while there's a context.
  late String _album;
  Uri? _art;

  /// Whether the header shows a download button (see [DownloadButton]).
  bool get _hasDownload {
    final id = downloadableItemAt(meditation.narration);
    return id != null && DownloadStore.instance.canDownload(id);
  }

  Meditation get meditation => widget.meditation;

  // A small, calm subset of the sound library to sit underneath.
  static List<Sound> get _ambientChoices => [
    for (final s in soundLibrary)
      if (const {
        'sound:Rainfall',
        'sound:Ocean waves',
        'sound:Deep focus',
      }.contains(s.id))
        s,
  ];

  /// The choices, plus the sound already playing when the session opened
  /// if it isn't one of them, so its chip shows it's on.
  List<Sound> get _chipSounds {
    final choices = _ambientChoices;
    final ambient = _ambient;
    if (ambient == null || choices.any((s) => s.asset == ambient)) {
      return choices;
    }
    return [
      ...choices,
      for (final s in soundLibrary)
        if (s.asset == ambient) s,
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Only the line that's showing needs to know about the clock: this
    // notifies when the prompt changes, not on every check.
    _clock.addListener(() {
      final next = _prompt;
      if (next != _promptShown.value) _promptShown.value = next;
    });
    // A sound already playing carries on under the session, and its chip
    // says so; a paused one would only come back on its own, so it stops.
    final player = SoundPlayer.instance;
    if (player.nowPlaying.value != null) {
      if (player.paused.value) {
        unawaited(player.stop());
      } else {
        _ambient = player.nowPlaying.value;
        player.playUnderneath();
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _album = context.l10n.nowPlayingMeditation(meditation.minutes);
      unawaited(_drawArt());
      SoundPlayer.instance.playOnce(chimeAsset);
      _setRunning(true);
    });
  }

  /// Starts or pauses everything together — the clock, the voice, the
  /// sound underneath and the lock screen — whichever button asked: the
  /// one on screen, the lock screen's, or an interruption.
  void _setRunning(bool run) {
    if (_done || run == _clock.running) return;
    final player = SoundPlayer.instance;
    final ambient = _ambient;
    final ambientHere = ambient != null && player.nowPlaying.value == ambient;
    if (run) {
      _clock.start();
      if (_hasVoice && _voice) {
        unawaited(
          player.resumeNarration(meditation.narration!, at: _clock.elapsed),
        );
      }
      if (ambientHere && player.paused.value) unawaited(player.resume());
    } else {
      _clock.pause();
      if (_hasVoice) unawaited(player.pauseNarration());
      if (ambientHere && !player.paused.value) unawaited(player.pause());
    }
    _publish();
    _syncEndNotice();
    if (mounted) setState(() {});
  }

  // ── The lock screen ──────────────────────────────────────────────────

  MediaItem get _item => MediaItem(
    id: meditation.id,
    title: meditation.title,
    artist: meditation.detail,
    album: _album,
    duration: Duration(minutes: meditation.minutes),
    displayDescription: meditation.detail,
    artUri: _art,
  );

  void _publish() {
    if (_done) return;
    final lockScreen = NowPlaying.instance;
    if (lockScreen.owner != this) lockScreen.show(this, _item, this);
    lockScreen.update(this, playing: _clock.running, position: _clock.elapsed);
  }

  Future<void> _drawArt() async {
    final art = await CoverArt.forItem(
      itemId: meditation.id,
      kind: ContentKind.meditation,
      icon: meditation.icon,
      accent: meditation.accent,
    );
    if (art == null || !mounted || _done) return;
    _art = art;
    NowPlaying.instance.updateItem(this, _item);
  }

  @override
  Future<void> play() async => _setRunning(true);

  @override
  Future<void> pause() async => _setRunning(false);

  /// Stop on the lock screen, or its notification swiped away: the session
  /// pauses and leaves the lock screen; play here brings it back.
  @override
  Future<void> stop() async {
    _setRunning(false);
    NowPlaying.instance.release(this);
  }

  // ── In the background ────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _inBackground = false;
        // Catch up at once on time that passed while the app was asleep.
        _clock.check();
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _inBackground = true;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        return;
    }
    _syncEndNotice();
  }

  /// See [SessionEndNotice]: set only while the session runs silently out
  /// of sight.
  void _syncEndNotice() {
    final silent = _ambient == null && !(_hasVoice && _voice);
    if (_inBackground && silent && _clock.running && !_done) {
      unawaited(
        SessionEndNotice.schedule(
          inTime: _clock.remaining,
          title: _completeTitle,
          body: meditation.title,
        ),
      );
    } else {
      unawaited(SessionEndNotice.cancel());
    }
  }

  late final String _completeTitle = context.l10n.meditationSessionComplete;

  void _finish({required bool late}) {
    if (_hasVoice) SoundPlayer.instance.stopNarration();
    NowPlaying.instance.release(this);
    unawaited(SessionEndNotice.cancel());
    // The screen moves on at once; the write and the audio follow. Waiting
    // on the network here froze the timer at 0:00 on a poor connection.
    if (mounted) setState(() => _done = true);
    // Keep the session, so it can add up to something.
    unawaited(
      (widget.practice ?? PracticeRepository()).logSession(
        kind: PracticeKind.meditation,
        slug: practiceSlug(meditation.id),
        title: meditation.title,
        minutes: meditation.minutes.toDouble(),
      ),
    );
    // Back from a long sleep, the chime would ring for nothing.
    unawaited(_closeOutAudio(chime: !late));
  }

  Future<void> _closeOutAudio({required bool chime}) async {
    try {
      await SoundPlayer.instance.stop();
      if (chime) await SoundPlayer.instance.playOnce(chimeAsset);
    } catch (e) {
      debugPrint('Meditation close-out audio failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _promptShown.dispose();
    _clock.dispose();
    NowPlaying.instance.release(this);
    unawaited(SessionEndNotice.cancel());
    // Also stops a sound still being fetched, so it can't start later.
    if (_ambient != null) SoundPlayer.instance.stop();
    if (_hasVoice) SoundPlayer.instance.stopNarration();
    super.dispose();
  }

  /// The instruction on screen right now; see the listener in initState.
  late final ValueNotifier<String> _promptShown = ValueNotifier(
    meditation.prompts.first.$2,
  );

  String get _prompt {
    final progress = _clock.progress;
    var text = meditation.prompts.first.$2;
    for (final (at, prompt) in meditation.prompts) {
      if (progress >= at) text = prompt;
    }
    return text;
  }

  String _clockText(Duration left) {
    // Rounded up, so it reads 0:01 until the very end, not 0:00 early.
    final s = (left.inMilliseconds / 1000).ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _pickAmbient(Sound? sound) async {
    if (sound != null && sound.premium && !isPremiumUser()) {
      showUpgradeSheet(
        context,
        item: sound.title,
        source: 'sheet:ambient',
        title: context.l10n.meditationSoundPremiumTitle,
        message: context.l10n.meditationSoundPremiumMessage(introOffer),
      );
      return;
    }
    final player = SoundPlayer.instance;
    if (sound == null) {
      if (_ambient == null) return;
      setState(() => _ambient = null);
      _syncEndNotice();
      await player.stop();
      return;
    }
    if (sound.asset == _ambient) return;
    // Chosen at once, so the chip answers the tap while a sound that isn't
    // on the phone yet is fetched — and so leaving now stops it.
    setState(() => _ambient = sound.asset);
    _syncEndNotice();
    try {
      final started = player.play(sound.asset, underneath: true);
      // Chosen while the session is paused: it waits for the session.
      if (!_clock.running) unawaited(player.pause());
      await started;
    } catch (e) {
      debugPrint('Ambient failed: $e');
      if (!mounted || _ambient != sound.asset) return;
      setState(() => _ambient = null);
      _syncEndNotice();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (e) {
            PremiumRequired() => DownloadStrings.premiumNeeded,
            MediaUnavailable() => DownloadStrings.needsConnection,
            _ => DownloadStrings.couldNotPlay,
          }),
        ),
      );
    }
  }

  /// Voice guide on or off. Turning it back on picks up where the voice
  /// was paused, so it stays roughly in step with the clock.
  Widget _voiceChip() {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: _voice ? c.ink : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _voice ? c.ink : c.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() => _voice = !_voice);
            if (!_voice) {
              SoundPlayer.instance.pauseNarration();
            } else if (_clock.running) {
              // Back in step with the clock, not where it was turned off.
              SoundPlayer.instance.resumeNarration(
                meditation.narration!,
                at: _clock.elapsed,
              );
            }
            _syncEndNotice();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _voice
                      ? Icons.record_voice_over_rounded
                      : Icons.voice_over_off_rounded,
                  size: 14,
                  color: _voice ? c.onInk : c.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  context.l10n.meditationVoiceChip,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: _voice ? c.onInk : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ambientChip(String label, Sound? sound) {
    final c = context.brand;
    final selected = _ambient == sound?.asset;
    final locked = sound != null && sound.premium && !isPremiumUser();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? c.ink : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? c.ink : c.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _pickAmbient(sound),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked) ...[
                  Icon(Icons.lock_rounded, size: 11, color: c.textMuted),
                  const SizedBox(width: 4),
                ],
                // Fetching a sound that isn't on the phone yet.
                if (sound != null)
                  ValueListenableBuilder<String?>(
                    valueListenable: SoundPlayer.instance.preparing,
                    builder: (context, preparing, _) =>
                        preparing == sound.asset
                        ? Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: selected ? c.onInk : c.textMuted,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: selected ? c.onInk : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _doneView() {
    final c = context.brand;
    return FlexibleColumn(
      children: [
        const Spacer(),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: c.tint(meditation.accent, 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 42,
            color: c.accent(meditation.accent),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.meditationSessionComplete,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.meditationCompleteBody(meditation.minutes),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.6),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.meditationAddedToHistory,
          style: TextStyle(fontSize: 12.5, color: c.accent(meditation.accent)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          child: SessionCloseOut(
            title: meditation.title,
            slug: practiceSlug(meditation.id),
            accent: meditation.accent,
            kind: PracticeKind.meditation,
          ),
        ),
      ],
    );
  }

  /// The ring and countdown, repainting with the session clock.
  Widget _progressRing() {
    final c = context.brand;
    final accent = c.accent(meditation.accent);
    return ListenableBuilder(
      listenable: _clock,
      builder: (context, _) {
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(240, 240),
                painter: _RingPainter(
                  progress: _clock.progress,
                  accent: accent,
                  track: c.tint(meditation.accent, 0.14),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(meditation.icon, size: 30, color: accent),
                  const SizedBox(height: 10),
                  Text(
                    _clockText(_clock.remaining),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    context.l10n.meditationRemaining,
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _runningView() {
    final c = context.brand;
    // An ink button turns off-white in the dark, like the logo's black
    // pillar; a coloured one keeps its white icon in both modes.
    final inkButton = meditation.accent == Pillars.black;
    return FlexibleColumn(
      children: [
        const Spacer(),
        // Only the ring and the clock redraw with the session; everything
        // below was being rebuilt sixty times a second for fifteen
        // minutes, which is a lot of work to display a still image.
        _progressRing(),
        const SizedBox(height: 34),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 44),
          // The builder sits outside the switcher, so the switcher is handed
          // a new line (a new key) each time and can cross-fade them.
          child: ValueListenableBuilder<String>(
            valueListenable: _promptShown,
            builder: (context, prompt, _) => AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              // Each instruction rises into place and the last one sinks
              // away, so guidance arrives at the pace of the session
              // rather than blinking between lines.
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.28),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.center,
                children: [...previous, ?current],
              ),
              child: Text(
                prompt,
                key: ValueKey(prompt),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: c.ink,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            children: [
              if (_hasVoice) _voiceChip(),
              _ambientChip(context.l10n.meditationNoSound, null),
              for (final s in _chipSounds) _ambientChip(s.title, s),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Material(
            color: inkButton ? c.ink : meditation.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _setRunning(!_clock.running),
              child: SizedBox(
                width: 68,
                height: 68,
                child: Icon(
                  _clock.running
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 36,
                  color: inkButton ? c.onInk : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The session's background, drifting behind it.
          Positioned.fill(
            child: SceneBackdrop(
              itemId: meditation.id,
              kind: ContentKind.meditation,
              intensity: _done ? 0.7 : 1,
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                      child: Row(
                        children: [
                          const BackChip(),
                          // Balances the download button, when there's one,
                          // so the title stays centred.
                          if (_hasDownload) const SizedBox(width: 42),
                          // Expanded rather than Spacer-Flexible-Spacer: with
                          // three flexible children the title only got a third
                          // of the row and ellipsised with space to spare.
                          Expanded(
                            child: Text(
                              meditation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.brand.ink,
                              ),
                            ),
                          ),
                          if (_hasDownload)
                            DownloadButton(
                              itemId: downloadableItemAt(meditation.narration),
                              accent: meditation.accent,
                            ),
                          // The size of the back chip, opposite it.
                          BackgroundPickerButton(
                            itemId: meditation.id,
                            kind: ContentKind.meditation,
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _done ? _doneView() : _runningView()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Progress ring: a faint full circle with the accent arc sweeping over it.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.accent,
    required this.track,
  });

  final double progress;
  final Color accent;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = this.track;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.accent != accent ||
      oldDelegate.track != track;
}
