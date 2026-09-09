import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';

/// The four logo pillars, softened into slow-moving washes of colour.
///
/// It sits behind a session and drifts on a long cycle — nothing snaps or
/// flashes, because the point is to be looked at with half-closed eyes for
/// fifteen minutes. Each pillar breathes at its own rate so the pattern
/// never visibly repeats.
///
/// Cheap on purpose: one painter, four radial gradients, no blur filters
/// (a `BackdropFilter` here would cost far more than it's worth), wrapped
/// in a `RepaintBoundary` so nothing above it repaints with the animation.
class PillarBackdrop extends StatefulWidget {
  const PillarBackdrop({
    super.key,
    this.accent,
    this.intensity = 1,
    this.breathing,
    this.swellFrom,
  });

  /// Pulled slightly toward this colour, so a session's own accent leads.
  final Color? accent;

  /// 0–1, scales how present the whole thing is.
  final double intensity;

  /// Optional animation to repaint with — the breathing screen passes its
  /// session controller so the backdrop redraws every frame.
  final Animation<double>? breathing;

  /// Maps [breathing]'s value to a 0–1 swell. The breathing screen passes
  /// the same curve that drives its circle, so the background inhales and
  /// exhales with the user instead of drifting on its own clock.
  final double Function(double)? swellFrom;

  @override
  State<PillarBackdrop> createState() => _PillarBackdropState();
}

class _PillarBackdropState extends State<PillarBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    // Long enough that the eye never catches the loop.
    duration: const Duration(seconds: 48),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  double get _swell {
    final value = widget.breathing?.value;
    if (value == null) return 0;
    return widget.swellFrom?.call(value) ?? value;
  }

  @override
  Widget build(BuildContext context) {
    // Someone who has asked their phone to reduce motion should not get a
    // drifting background — they get the same picture, held still.
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_drift.isAnimating) _drift.stop();
      return RepaintBoundary(
        child: CustomPaint(
          painter: _PillarPainter(
            t: 0.2,
            swell: 0,
            accent: widget.accent,
            intensity: widget.intensity,
          ),
          size: Size.infinite,
        ),
      );
    }
    if (!_drift.isAnimating) _drift.repeat();

    final listenable = widget.breathing == null
        ? _drift
        : Listenable.merge([_drift, widget.breathing!]);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: listenable,
        builder: (context, _) => CustomPaint(
          painter: _PillarPainter(
            t: _drift.value,
            swell: _swell,
            accent: widget.accent,
            intensity: widget.intensity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PillarPainter extends CustomPainter {
  _PillarPainter({
    required this.t,
    required this.swell,
    required this.accent,
    required this.intensity,
  });

  /// 0–1 through the drift cycle.
  final double t;

  /// 0–1 breathing swell, when one was supplied.
  final double swell;
  final Color? accent;
  final double intensity;

  /// Where each pillar sits across the width, and how fast it drifts.
  static const _lanes = [0.11, 0.37, 0.63, 0.89];
  static const _rates = [1.0, 0.72, 1.31, 0.53];
  static const _phases = [0.0, 0.35, 0.6, 0.85];

  @override
  void paint(Canvas canvas, Size size) {
    final tau = math.pi * 2;
    for (var i = 0; i < Brand.pillarColors.length; i++) {
      var colour = Brand.pillarColors[i];
      if (accent != null) {
        // Nudge every wash toward the session's colour so the screen reads
        // as one thing rather than four.
        colour = Color.lerp(colour, accent!, 0.35)!;
      }

      final drift = math.sin(tau * (t * _rates[i] + _phases[i]));
      final bob = math.cos(tau * (t * _rates[i] * 0.6 + _phases[i]));

      final centre = Offset(
        size.width * (_lanes[i] + drift * 0.05),
        size.height * (0.46 + bob * 0.06 + swell * 0.04),
      );

      // Four upright bars, like the logo — but enormous and soft-edged,
      // so they read as light rather than as graphics. A radial gradient
      // stretched into a tall rect gives the soft edge for free; a real
      // blur filter would cost far more for the same look.
      // Narrow enough to read as four columns rather than one wash, tall
      // enough to run off both ends of the screen.
      final width = size.width * (0.34 + 0.04 * drift);
      final height =
          size.height * (0.95 + 0.10 * bob + 0.16 * swell) * intensity;
      final rect = Rect.fromCenter(
        center: centre,
        width: width,
        height: height,
      );

      // Ink would read as a grey smudge; keep it faintest.
      final isInk = Brand.pillarColors[i] == Brand.ink;
      final peak = (isInk ? 0.07 : 0.20) * intensity;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colour.withValues(alpha: peak),
            colour.withValues(alpha: peak * 0.5),
            colour.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_PillarPainter old) =>
      old.t != t ||
      old.swell != swell ||
      old.accent != accent ||
      old.intensity != intensity;
}
