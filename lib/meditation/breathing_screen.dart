import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../brand_layout.dart';
import '../sounds/sound_player.dart';
import '../practice/practice_repository.dart';
import '../practice/session_close_out.dart';
import 'meditation_catalog.dart';
import 'pillar_backdrop.dart';

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
  const BreathingScreen({super.key, required this.pattern, this.practice});

  final BreathPattern pattern;

  /// Injectable so the logging can be verified without a backend.
  final PracticeRepository? practice;

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  /// One controller for the life of the screen, re-timed and reset for
  /// each run. A SingleTickerProviderStateMixin hands out exactly one
  /// ticker, so building a new controller per run asserted on the second
  /// Begin (and, after a finished run, leaked the previous controller).
  late final AnimationController _session = AnimationController(
    vsync: this,
    duration: Duration(minutes: _minutes),
  );
  int _minutes = 3;

  /// A session is on screen (running or paused), as opposed to the setup
  /// or the well-done view.
  bool _running = false;
  bool _done = false;
  _Phase? _lastPhase;

  BreathPattern get pattern => widget.pattern;

  @override
  void initState() {
    super.initState();
    _session
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _start() {
    SoundPlayer.instance.playOnce(chimeAsset);
    _lastPhase = null;
    _session
      ..duration = Duration(minutes: _minutes)
      ..reset();
    setState(() {
      _done = false;
      _running = true;
    });
    _session.forward();
  }

  void _end() {
    _session
      ..stop()
      ..reset();
    setState(() => _running = false);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    SoundPlayer.instance.playOnce(chimeAsset);
    // Keep the session, so it can add up to something.
    (widget.practice ?? PracticeRepository()).logSession(
      kind: PracticeKind.breathing,
      slug: pattern.title,
      title: pattern.title,
      minutes: _minutes.toDouble(),
    );
    setState(() {
      _done = true;
      _running = false;
    });
  }

  double get _elapsed => _session.value * (_session.duration?.inSeconds ?? 0);

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

  /// The breath scale at a point in the session, 0 (smallest) to 1
  /// (fullest) — the same curve the circle uses, so the backdrop can
  /// breathe in step with it.
  double _swellAt(double sessionValue) {
    final elapsed = sessionValue * (_session.duration?.inSeconds ?? 0);
    final (phase, progress) = _phaseAt(elapsed);
    const small = 0.55;
    return (_scaleFor(phase, progress) - small) / (1 - small);
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
    final c = context.brand;
    final selected = _minutes == minutes;
    return Material(
      color: selected ? c.ink : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? c.ink : c.border,
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
              color: selected ? c.onInk : c.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _circle({required double scale, required Widget center}) {
    // A drawing, not a card wash: the accent's shade for the mode at the
    // same strengths in both, so the words on it stay readable in the dark.
    final fill = context.brand.art(pattern.accent);
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
                color: fill.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
          ),
          Container(
            width: 260 * scale,
            height: 260 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill.withValues(alpha: 0.16),
            ),
          ),
          Container(
            width: 150 * scale,
            height: 150 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill.withValues(alpha: 0.28),
            ),
          ),
          center,
        ],
      ),
    );
  }

  Widget _setupView() {
    final c = context.brand;
    return FlexibleColumn(
      children: [
        const Spacer(),
        _circle(
          scale: 0.75,
          center: Icon(
            Icons.air_rounded,
            size: 44,
            color: c.accent(pattern.accent),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          pattern.rhythmLabel,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: c.accent(pattern.accent),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            pattern.detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: c.textMuted,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 26),
        // Wrap, not Row: at larger text sizes three chips no longer fit
        // a narrow phone, and they drop to a second line instead of
        // running off the edge.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _durationChip(1),
              _durationChip(3),
              _durationChip(5),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 26),
          child: ElevatedButton(onPressed: _start, child: const Text('Begin')),
        ),
      ],
    );
  }

  Widget _doneView() {
    final c = context.brand;
    final cycles = (_minutes * 60 / pattern.cycleSeconds).floor();
    return FlexibleColumn(
      children: [
        const Spacer(),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: c.tint(pattern.accent, 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_rounded,
            size: 42,
            color: c.accent(pattern.accent),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Well done',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$_minutes minute${_minutes == 1 ? '' : 's'} · about $cycles '
          'breath cycles.\nNotice how you feel right now.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: c.textMuted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Added to your practice history.',
          style: TextStyle(fontSize: 12.5, color: c.accent(pattern.accent)),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
          child: OutlinedButton(
            onPressed: _start,
            style: OutlinedButton.styleFrom(
              foregroundColor: c.ink,
              minimumSize: const Size.fromHeight(52),
              side: BorderSide(color: c.border, width: 1.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Go again'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
          child: SessionCloseOut(title: pattern.title, accent: pattern.accent),
        ),
      ],
    );
  }

  Widget _runningView() {
    final c = context.brand;
    // An ink button turns off-white in the dark, like the logo's black
    // pillar; a coloured one keeps its white icon in both modes.
    final inkButton = pattern.accent == Pillars.black;
    final session = _session;
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final elapsed = _elapsed;
        final total = session.duration!.inSeconds.toDouble();
        final (phase, progress) = _phaseAt(elapsed);
        final scale = _scaleFor(phase, progress);
        return FlexibleColumn(
          children: [
            const Spacer(),
            _circle(
              scale: scale,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    phase.label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _clock(total - elapsed),
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textMuted,
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
                color: c.accent(pattern.accent),
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
                    onPressed: _end,
                    icon: Icon(
                      Icons.stop_rounded,
                      size: 30,
                      color: c.textMuted,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Material(
                    color: inkButton ? c.ink : pattern.accent,
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
                          color: inkButton ? c.onInk : Colors.white,
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
    } else if (_running) {
      body = _runningView();
    } else {
      body = _setupView();
    }
    return Scaffold(
      body: Stack(
        children: [
          // The logo pillars behind the session — and while one is running
          // they swell with the same animation as the circle, so the whole
          // screen breathes rather than just the middle of it.
          Positioned.fill(
            child: PillarBackdrop(
              accent: pattern.accent,
              intensity: _running ? 1 : 0.7,
              breathing: _running ? _session : null,
              swellFrom: _swellAt,
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
                          // Expanded rather than two Spacers: with three
                          // flexible children a long title ellipsised early.
                          Expanded(
                            child: Text(
                              pattern.title,
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
        ],
      ),
    );
  }
}
