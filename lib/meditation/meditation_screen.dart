import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../billing/pricing_copy.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../brand_layout.dart';
import '../home/home_ui.dart';
import '../practice/practice_repository.dart';
import '../practice/session_close_out.dart';
import '../sounds/sound_player.dart';
import '../sounds/sounds_catalog.dart';
import 'meditation_catalog.dart';
import 'pillar_backdrop.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _session;
  bool _done = false;
  String? _ambient; // asset of the chosen background sound

  Meditation get meditation => widget.meditation;

  // A small, calm subset of the sound library to sit underneath.
  static final _ambientChoices = [
    for (final s in soundsCatalog)
      if (const {'Rainfall', 'Ocean waves', 'Deep focus'}.contains(s.title)) s,
  ];

  @override
  void initState() {
    super.initState();
    _session = AnimationController(
      vsync: this,
      duration: Duration(minutes: meditation.minutes),
    );
    _session.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SoundPlayer.instance.playOnce(chimeAsset);
      _session.forward();
    });
  }

  Future<void> _finish() async {
    await SoundPlayer.instance.stop();
    await SoundPlayer.instance.playOnce(chimeAsset);
    // Keep the session, so it can add up to something.
    await (widget.practice ?? PracticeRepository()).logSession(
      kind: PracticeKind.meditation,
      slug: meditation.title,
      title: meditation.title,
      minutes: meditation.minutes.toDouble(),
    );
    if (mounted) setState(() => _done = true);
  }

  @override
  void dispose() {
    _session.dispose();
    if (_ambient != null) SoundPlayer.instance.stop();
    super.dispose();
  }

  String get _prompt {
    final progress = _session.value;
    var text = meditation.prompts.first.$2;
    for (final (at, prompt) in meditation.prompts) {
      if (progress >= at) text = prompt;
    }
    return text;
  }

  String _clock(double seconds) {
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _pickAmbient(Sound? sound) async {
    if (sound != null && sound.premium && !isPremiumUser()) {
      showUpgradeSheet(
        context,
        title: 'This sound is part of Premium',
        message:
            'Free includes one sound to try. Premium unlocks the whole '
            'library — and $introOffer.',
      );
      return;
    }
    try {
      if (sound == null) {
        await SoundPlayer.instance.stop();
        setState(() => _ambient = null);
      } else {
        await SoundPlayer.instance.play(sound.asset);
        setState(() => _ambient = sound.asset);
      }
    } catch (e) {
      debugPrint('Ambient failed: $e');
    }
  }

  Widget _ambientChip(String label, Sound? sound) {
    final selected = _ambient == sound?.asset;
    final locked = sound != null && sound.premium && !isPremiumUser();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? Brand.ink : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? Brand.ink : Brand.border,
            width: 1.2,
          ),
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
                  const Icon(
                    Icons.lock_rounded,
                    size: 11,
                    color: Brand.textMuted,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : Brand.textMuted,
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
    return FlexibleColumn(
      children: [
        const Spacer(),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: meditation.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 42, color: meditation.accent),
        ),
        const SizedBox(height: 24),
        const Text(
          'Session complete',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${meditation.minutes} quiet minutes, just for you.\n'
          'Carry a little of this with you.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Brand.textMuted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Added to your practice history.',
          style: TextStyle(fontSize: 12.5, color: meditation.accent),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          child: SessionCloseOut(
            title: meditation.title,
            accent: meditation.accent,
          ),
        ),
      ],
    );
  }

  /// The ring and countdown, repainting with the session clock.
  Widget _progressRing() {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final total = _session.duration!.inSeconds.toDouble();
        final remaining = total * (1 - _session.value);
        return SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(240, 240),
                painter: _RingPainter(
                  progress: _session.value,
                  accent: meditation.accent,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(meditation.icon, size: 30, color: meditation.accent),
                  const SizedBox(height: 10),
                  Text(
                    _clock(remaining),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Brand.ink,
                    ),
                  ),
                  const Text(
                    'remaining',
                    style: TextStyle(fontSize: 12, color: Brand.textMuted),
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
          child: AnimatedSwitcher(
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
              _prompt,
              key: ValueKey(_prompt),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: Brand.ink,
                height: 1.6,
                fontWeight: FontWeight.w500,
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
              _ambientChip('No sound', null),
              for (final s in _ambientChoices) _ambientChip(s.title, s),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.only(bottom: 26),
          child: Material(
            color: meditation.accent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() {
                _session.isAnimating ? _session.stop() : _session.forward();
              }),
              child: SizedBox(
                width: 68,
                height: 68,
                child: Icon(
                  _session.isAnimating
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 36,
                  color: Colors.white,
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
          // The four logo pillars, drifting behind the session.
          Positioned.fill(
            child: PillarBackdrop(
              accent: meditation.accent,
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
                          // Expanded rather than Spacer-Flexible-Spacer: with
                          // three flexible children the title only got a third
                          // of the row and ellipsised with space to spare.
                          Expanded(
                            child: Text(
                              meditation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Brand.ink,
                              ),
                            ),
                          ),
                          // Balances the back chip so the title sits centred.
                          const SizedBox(width: 42),
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
  const _RingPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..color = accent.withValues(alpha: 0.14);
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
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}
