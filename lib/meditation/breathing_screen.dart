import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../sounds/sound_player.dart';
import 'meditation_catalog.dart';

enum _Phase { inhale, holdIn, exhale, holdOut }

extension on _Phase {
  String get label => switch (this) {
        _Phase.inhale => 'Breathe in',
        _Phase.holdIn => 'Hold',
        _Phase.exhale => 'Breathe out',
        _Phase.holdOut => 'Hold',
      };
}

/// Guided breathing: a circle that grows and shrinks with the pattern's
/// rhythm. Pick a length, breathe along, finish with a chime.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key, required this.pattern});

  final BreathPattern pattern;

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  AnimationController? _session;
  int _minutes = 3;
  bool _done = false;
  _Phase? _lastPhase;

  BreathPattern get pattern => widget.pattern;

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  void _start() {
    SoundPlayer.instance.playOnce(chimeAsset);
    final controller = AnimationController(
      vsync: this,
      duration: Duration(minutes: _minutes),
    );
    controller.addListener(_onTick);
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        SoundPlayer.instance.playOnce(chimeAsset);
        setState(() => _done = true);
      }
    });
    setState(() {
      _done = false;
      _session = controller..forward();
    });
  }

  double get _elapsed =>
      (_session?.value ?? 0) * (_session?.duration?.inSeconds ?? 0);

  /// (phase, progress within phase 0..1)
  (_Phase, double) _phaseAt(double elapsed) {
    final cycle = pattern.cycleSeconds.toDouble();
    var t = elapsed % cycle;
    final segments = [
      (_Phase.inhale, pattern.inhale.toDouble()),
      (_Phase.holdIn, pattern.holdIn.toDouble()),
      (_Phase.exhale, pattern.exhale.toDouble()),
      (_Phase.holdOut, pattern.holdOut.toDouble()),
    ];
    for (final (phase, length) in segments) {
      if (length <= 0) continue;
      if (t < length) return (phase, t / length);
      t -= length;
    }
    return (_Phase.inhale, 0);
  }

  void _onTick() {
    final (phase, _) = _phaseAt(_elapsed);
    if (phase != _lastPhase) {
      _lastPhase = phase;
      HapticFeedback.lightImpact();
    }
  }

  double _scaleFor(_Phase phase, double progress) {
    const small = 0.55;
    final eased = Curves.easeInOut.transform(progress);
    return switch (phase) {
      _Phase.inhale => small + (1 - small) * eased,
      _Phase.holdIn => 1.0,
      _Phase.exhale => 1 - (1 - small) * eased,
      _Phase.holdOut => small,
    };
  }

  String _clock(double seconds) {
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _durationChip(int minutes) {
    final selected = _minutes == minutes;
    return Material(
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
        onTap: () => setState(() => _minutes = minutes),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '$minutes min',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : Brand.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle({required double scale, required Widget center}) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: pattern.accent.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: 260 * scale,
            height: 260 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pattern.accent.withValues(alpha: 0.16),
            ),
          ),
          Container(
            width: 150 * scale,
            height: 150 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: pattern.accent.withValues(alpha: 0.28),
            ),
          ),
          center,
        ],
      ),
    );
  }

  Widget _setupView() {
    return Column(
      children: [
        const Spacer(),
        _circle(
          scale: 0.75,
          center: Icon(Icons.air_rounded, size: 44, color: pattern.accent),
        ),
        const SizedBox(height: 30),
        Text(
          pattern.rhythmLabel,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: pattern.accent,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            pattern.detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Brand.textMuted,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _durationChip(1),
            const SizedBox(width: 10),
            _durationChip(3),
            const SizedBox(width: 10),
            _durationChip(5),
          ],
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
          child: ElevatedButton(
            onPressed: _start,
            child: const Text('Begin'),
          ),
        ),
      ],
    );
  }

  Widget _doneView() {
    final cycles = (_minutes * 60 / pattern.cycleSeconds).floor();
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: pattern.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 42, color: pattern.accent),
        ),
        const SizedBox(height: 24),
        const Text(
          'Well done',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$_minutes minute${_minutes == 1 ? '' : 's'} · about $cycles '
          'breath cycles.\nNotice how you feel right now.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Brand.textMuted,
            height: 1.6,
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
          child: ElevatedButton(
            onPressed: _start,
            child: const Text('Go again'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _runningView() {
    final session = _session!;
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final elapsed = _elapsed;
        final total = session.duration!.inSeconds.toDouble();
        final (phase, progress) = _phaseAt(elapsed);
        final scale = _scaleFor(phase, progress);
        return Column(
          children: [
            const Spacer(),
            _circle(
              scale: scale,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    phase.label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Brand.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _clock(total - elapsed),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Brand.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            Text(
              pattern.rhythmLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: pattern.accent,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 26),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'End session',
                    onPressed: () {
                      session.stop();
                      setState(() {
                        _session!.dispose();
                        _session = null;
                      });
                    },
                    icon: const Icon(
                      Icons.stop_rounded,
                      size: 30,
                      color: Brand.textMuted,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Material(
                    color: pattern.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() {
                        session.isAnimating
                            ? session.stop()
                            : session.forward();
                      }),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: Icon(
                          session.isAnimating
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  const SizedBox(width: 46),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_done) {
      body = _doneView();
    } else if (_session != null) {
      body = _runningView();
    } else {
      body = _setupView();
    }
    return Scaffold(
      body: SafeArea(
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
                      const Spacer(),
                      Text(
                        pattern.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 42),
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
