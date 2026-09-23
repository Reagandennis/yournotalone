import 'dart:math';

import 'package:flutter/material.dart';

import '../brand.dart';
import 'mood_scale.dart';

/// A mood as a small character: a soft, slightly lopsided blob in the
/// mood's colour, with a face drawn in two or three ink strokes.
///
/// Drawn in code, not from an image, so it stays crisp at any size and
/// its colours are the same [moodLevels] colours the history screen uses.
/// Each mood has its own shape as well as its own expression — the awful
/// one sags, the great one is top-heavy and bouncy — so they read apart
/// even at the size of a list icon.
class MoodFace extends StatelessWidget {
  const MoodFace({
    super.key,
    required this.level,
    required this.size,
    this.dimmed = false,
  });

  final MoodLevel level;
  final double size;

  /// Faded, for the moods that weren't picked once one has been.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: dimmed ? 0.38 : 1,
      duration: const Duration(milliseconds: 220),
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _MoodFacePainter(
            level: level,
            shape: _shapeFor(level),
            expression: _expressionFor(level),
          ),
        ),
      ),
    );
  }
}

/// How a blob departs from a circle: a few low-frequency ripples on the
/// radius plus a vertical squash. Amplitudes stay small so it looks like
/// a soft body, not a splat.
class _BlobShape {
  const _BlobShape({
    this.squash = 1,
    this.a1 = 0,
    this.p1 = 0,
    this.a2 = 0,
    this.p2 = 0,
    this.a3 = 0,
    this.p3 = 0,
  });

  final double squash;
  final double a1, p1, a2, p2, a3, p3;

  double radius(double t) =>
      1 + a1 * cos(t - p1) + a2 * cos(2 * t - p2) + a3 * cos(3 * t - p3);
}

enum _Eyes { squeezed, dots, closed }

enum _Mouth { deepFrown, frown, flat, smile, grin }

class _Expression {
  const _Expression(this.eyes, this.mouth);

  final _Eyes eyes;
  final _Mouth mouth;
}

_BlobShape _shapeFor(MoodLevel level) => switch (level.label) {
  // Wider than tall and heavier at the bottom: sagging.
  'Awful' => const _BlobShape(
    squash: 0.88,
    a1: 0.06,
    p1: pi / 2,
    a2: 0.05,
    a3: 0.02,
    p3: 1.1,
  ),
  // Leaning a little, as if it can't quite sit up.
  'Low' => const _BlobShape(
    a1: 0.05,
    p1: 2.6,
    a2: 0.02,
    p2: 2.0,
    a3: 0.045,
    p3: 0.4,
  ),
  // Nearly round, gently uneven.
  'Okay' => const _BlobShape(
    a1: 0.02,
    p1: 0.3,
    a2: 0.03,
    p2: 0.8,
    a3: 0.04,
    p3: 2.2,
  ),
  // A touch taller: sitting up.
  'Good' => const _BlobShape(
    squash: 1.06,
    a1: 0.025,
    p1: -1.0,
    a3: 0.045,
    p3: 1.2,
  ),
  // Top-heavy and bouncy.
  _ => const _BlobShape(
    a1: 0.065,
    p1: -pi / 2,
    a2: 0.02,
    p2: 0.5,
    a3: 0.04,
    p3: 2.0,
  ),
};

_Expression _expressionFor(MoodLevel level) => switch (level.label) {
  'Awful' => const _Expression(_Eyes.squeezed, _Mouth.deepFrown),
  'Low' => const _Expression(_Eyes.dots, _Mouth.frown),
  'Okay' => const _Expression(_Eyes.dots, _Mouth.flat),
  'Good' => const _Expression(_Eyes.dots, _Mouth.smile),
  _ => const _Expression(_Eyes.closed, _Mouth.grin),
};

class _MoodFacePainter extends CustomPainter {
  const _MoodFacePainter({
    required this.level,
    required this.shape,
    required this.expression,
  });

  final MoodLevel level;
  final _BlobShape shape;
  final _Expression expression;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide * 0.46;

    // Body.
    final body = Path();
    const steps = 72;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * pi;
      final radius = r * shape.radius(t);
      final p = c + Offset(cos(t) * radius, sin(t) * radius * shape.squash);
      if (i == 0) {
        body.moveTo(p.dx, p.dy);
      } else {
        body.lineTo(p.dx, p.dy);
      }
    }
    body.close();

    // A single lighter tint of the same colour towards the top-left gives
    // the body some roundness without turning it into a glossy sphere.
    final light = Color.lerp(level.color, Colors.white, 0.3)!;
    canvas.drawPath(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.5),
          radius: 1.05,
          colors: [light, level.color],
          stops: const [0.0, 0.8],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Face.
    final ink = Paint()
      ..color = Brand.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.078
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = Brand.ink;

    final eyeY = c.dy - r * 0.14;
    final eyeDx = r * 0.36;
    final eyeW = r * 0.2;
    for (final x in [c.dx - eyeDx, c.dx + eyeDx]) {
      switch (expression.eyes) {
        case _Eyes.dots:
          canvas.drawCircle(Offset(x, eyeY), size.shortestSide * 0.052, dot);
        case _Eyes.closed:
          // A contented "∩".
          canvas.drawPath(
            Path()
              ..moveTo(x - eyeW, eyeY + r * 0.04)
              ..quadraticBezierTo(
                x,
                eyeY - r * 0.26,
                x + eyeW,
                eyeY + r * 0.04,
              ),
            ink,
          );
        case _Eyes.squeezed:
          // Shut tight: a "∪".
          canvas.drawPath(
            Path()
              ..moveTo(x - eyeW, eyeY - r * 0.06)
              ..quadraticBezierTo(
                x,
                eyeY + r * 0.22,
                x + eyeW,
                eyeY - r * 0.06,
              ),
            ink,
          );
      }
    }

    final mouthY = c.dy + r * 0.32;
    final mouth = Path();
    switch (expression.mouth) {
      case _Mouth.deepFrown:
        mouth
          ..moveTo(c.dx - r * 0.32, mouthY + r * 0.12)
          ..quadraticBezierTo(
            c.dx,
            mouthY - r * 0.26,
            c.dx + r * 0.32,
            mouthY + r * 0.12,
          );
      case _Mouth.frown:
        mouth
          ..moveTo(c.dx - r * 0.28, mouthY + r * 0.06)
          ..quadraticBezierTo(
            c.dx,
            mouthY - r * 0.1,
            c.dx + r * 0.28,
            mouthY + r * 0.06,
          );
      case _Mouth.flat:
        mouth
          ..moveTo(c.dx - r * 0.26, mouthY)
          ..lineTo(c.dx + r * 0.26, mouthY);
      case _Mouth.smile:
        mouth
          ..moveTo(c.dx - r * 0.3, mouthY - r * 0.06)
          ..quadraticBezierTo(
            c.dx,
            mouthY + r * 0.16,
            c.dx + r * 0.3,
            mouthY - r * 0.06,
          );
      case _Mouth.grin:
        mouth
          ..moveTo(c.dx - r * 0.38, mouthY - r * 0.1)
          ..quadraticBezierTo(
            c.dx,
            mouthY + r * 0.34,
            c.dx + r * 0.38,
            mouthY - r * 0.1,
          );
    }
    canvas.drawPath(mouth, ink);
  }

  @override
  bool shouldRepaint(_MoodFacePainter old) =>
      old.level != level || old.shape != shape || old.expression != expression;
}
