import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';

/// Which abstract composition to draw.
enum CbtArtKind {
  thoughts,
  traps,
  activity,
  worry,
  grounding,
  problem,
  learn,
  resources,
}

/// Abstract, geometric illustrations for the CBT toolkit — the "shapes and
/// blobs" style of the reference design. Drawn in code, like [TherapyArt]:
/// they stay sharp at any size, weigh nothing, and carry no stock-image
/// licence. Each one is composed for a square [size] and is meant to sit
/// flush against the right edge of a card.
class CbtArt extends StatelessWidget {
  const CbtArt({super.key, required this.kind, this.size = 96});

  final CbtArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(painter: _CbtArtPainter(kind)),
      ),
    );
  }
}

// Soft tints of the pillar colours, for the quieter shapes.
const _peach = Color(0xFFF7C4B4);
const _sky = Color(0xFFC7D5F1);
const _sand = Color(0xFFFCE3A3);
const _mint = Color(0xFFBFE3CF);
const _green = Color(0xFF3E9B5B);
const _stone = Color(0xFFD9D4CC);

class _CbtArtPainter extends CustomPainter {
  const _CbtArtPainter(this.kind);

  final CbtArtKind kind;

  Paint _fill(Color colour) => Paint()
    ..color = colour
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // Everything below works in a 0..1 square.
    canvas.scale(s);
    switch (kind) {
      case CbtArtKind.thoughts:
        _thoughts(canvas);
      case CbtArtKind.traps:
        _traps(canvas);
      case CbtArtKind.activity:
        _activity(canvas);
      case CbtArtKind.worry:
        _worry(canvas);
      case CbtArtKind.grounding:
        _grounding(canvas);
      case CbtArtKind.problem:
        _problem(canvas);
      case CbtArtKind.learn:
        _learn(canvas);
      case CbtArtKind.resources:
        _resources(canvas);
    }
  }

  /// A thought rising out of a solid base: three bubbles climbing away
  /// from a yellow block, like the reference's mindful-parent card.
  void _thoughts(Canvas c) {
    c.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(0.42, 0.56, 0.62, 0.5),
        topLeft: const Radius.circular(0.14),
        topRight: const Radius.circular(0.04),
      ),
      _fill(Brand.yellow),
    );
    c.drawCircle(const Offset(0.5, 0.5), 0.06, _fill(_peach));
    c.drawCircle(const Offset(0.36, 0.36), 0.09, _fill(_peach));
    c.drawCircle(const Offset(0.5, 0.17), 0.16, _fill(Brand.red));
    c.drawRect(const Rect.fromLTWH(0.82, 0.3, 0.14, 0.14), _fill(Brand.blue));
  }

  /// Arcs curling inward with a small red dot caught in the middle — the
  /// pull of a thinking trap.
  void _traps(Canvas c) {
    final stroke = Paint()
      ..color = Brand.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.11
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    const centre = Offset(0.56, 0.56);
    c.drawArc(Rect.fromCircle(center: centre, radius: 0.42), math.pi * 0.9,
        math.pi * 1.35, false, stroke);
    c.drawArc(Rect.fromCircle(center: centre, radius: 0.24), math.pi * 0.3,
        math.pi * 1.3, false, stroke..color = _sky);
    c.drawCircle(centre, 0.08, _fill(Brand.red));
    final tri = Path()
      ..moveTo(0.06, 0.18)
      ..lineTo(0.3, 0.06)
      ..lineTo(0.26, 0.34)
      ..close();
    c.drawPath(tri, _fill(Brand.yellow));
  }

  /// A sun coming up over a hill: doing one small thing today.
  void _activity(Canvas c) {
    final rays = Paint()
      ..color = _sand
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06
      ..strokeCap = StrokeCap.round;
    const sun = Offset(0.6, 0.5);
    for (var i = 0; i < 7; i++) {
      final a = math.pi + i * math.pi / 6;
      c.drawLine(
        sun + Offset(math.cos(a), math.sin(a)) * 0.34,
        sun + Offset(math.cos(a), math.sin(a)) * 0.46,
        rays,
      );
    }
    c.drawCircle(sun, 0.25, _fill(Brand.yellow));
    c.drawOval(const Rect.fromLTWH(0.1, 0.62, 1.1, 0.7), _fill(_green));
    c.drawOval(const Rect.fromLTWH(-0.2, 0.74, 0.7, 0.5), _fill(_mint));
    c.drawCircle(const Offset(0.16, 0.3), 0.07, _fill(Brand.red));
  }

  /// A clock face with a little cloud parked beside it: worry has a time
  /// and a place.
  void _worry(Canvas c) {
    const centre = Offset(0.62, 0.6);
    c.drawCircle(centre, 0.36, _fill(Brand.blue));
    c.drawCircle(centre, 0.28, _fill(_sky));
    final hand = Paint()
      ..color = Brand.ink
      ..strokeWidth = 0.05
      ..strokeCap = StrokeCap.round;
    c.drawLine(centre, centre + const Offset(0, -0.2), hand);
    c.drawLine(centre, centre + const Offset(0.15, 0.08), hand);
    c.drawCircle(centre, 0.04, _fill(Brand.ink));
    // The cloud: three overlapping circles on a flat base.
    final cloud = _fill(_stone);
    c.drawCircle(const Offset(0.18, 0.24), 0.11, cloud);
    c.drawCircle(const Offset(0.3, 0.18), 0.13, cloud);
    c.drawCircle(const Offset(0.4, 0.27), 0.09, cloud);
    c.drawRect(const Rect.fromLTWH(0.1, 0.24, 0.36, 0.12), cloud);
    c.drawCircle(const Offset(0.9, 0.16), 0.08, _fill(Brand.yellow));
  }

  /// Stacked pebbles — steady, and here. Modelled on the reference's
  /// "challenging times" card.
  void _grounding(Canvas c) {
    c.drawOval(const Rect.fromLTWH(0.1, 0.78, 0.86, 0.3), _fill(_stone));
    c.drawOval(const Rect.fromLTWH(0.2, 0.46, 0.66, 0.42), _fill(Brand.yellow));
    c.drawOval(const Rect.fromLTWH(0.3, 0.22, 0.44, 0.3), _fill(_sand));
    c.drawCircle(const Offset(0.52, 0.12), 0.11, _fill(Brand.ink));
    // A closed, resting eye on the big pebble.
    final eye = Paint()
      ..color = Brand.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.035
      ..strokeCap = StrokeCap.round;
    c.drawArc(const Rect.fromLTWH(0.4, 0.58, 0.26, 0.14), 0.15 * math.pi,
        0.7 * math.pi, false, eye);
    c.drawCircle(const Offset(0.1, 0.36), 0.06, _fill(Brand.blue));
  }

  /// A spark above a solid block: the moment a way through shows itself.
  void _problem(Canvas c) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.34, 0.62, 0.5, 0.5),
        const Radius.circular(0.1),
      ),
      _fill(Brand.blue),
    );
    c.drawRect(const Rect.fromLTWH(0.46, 0.5, 0.26, 0.14), _fill(_sky));
    // Four-point spark.
    final spark = Path();
    const cx = 0.58, cy = 0.28, r = 0.26, pinch = 0.07;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final d = i.isEven ? r : pinch;
      final p = Offset(cx + math.cos(a) * d, cy + math.sin(a) * d);
      i == 0 ? spark.moveTo(p.dx, p.dy) : spark.lineTo(p.dx, p.dy);
    }
    spark.close();
    c.drawPath(spark, _fill(Brand.yellow));
    c.drawCircle(const Offset(0.14, 0.7), 0.09, _fill(Brand.red));
    c.drawRect(const Rect.fromLTWH(0.9, 0.12, 0.1, 0.1), _fill(_peach));
  }

  /// An open book: two leaning pages and a sun to read by.
  void _learn(Canvas c) {
    c.drawCircle(const Offset(0.28, 0.3), 0.2, _fill(Brand.yellow));
    c.save();
    c.translate(0.52, 0.98);
    c.rotate(-0.22);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-0.4, -0.46, 0.4, 0.5),
        const Radius.circular(0.05),
      ),
      _fill(Brand.red),
    );
    c.restore();
    c.save();
    c.translate(0.52, 0.98);
    c.rotate(0.22);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, -0.46, 0.4, 0.5),
        const Radius.circular(0.05),
      ),
      _fill(_peach),
    );
    c.restore();
    c.drawRect(const Rect.fromLTWH(0.49, 0.52, 0.06, 0.46), _fill(Brand.ink));
    c.drawCircle(const Offset(0.86, 0.22), 0.06, _fill(Brand.blue));
  }

  /// A signpost pointing onward: the good places to go next.
  void _resources(Canvas c) {
    c.drawArc(const Rect.fromLTWH(0.4, 0.4, 0.8, 0.8), math.pi, math.pi, true,
        _fill(Brand.red));
    c.drawRect(const Rect.fromLTWH(0.3, 0.42, 0.08, 0.6), _fill(Brand.ink));
    final sign = Path()
      ..moveTo(0.14, 0.2)
      ..lineTo(0.6, 0.2)
      ..lineTo(0.72, 0.32)
      ..lineTo(0.6, 0.44)
      ..lineTo(0.14, 0.44)
      ..close();
    c.drawPath(sign, _fill(Brand.blue));
    c.drawCircle(const Offset(0.86, 0.14), 0.07, _fill(Brand.yellow));
    c.drawCircle(const Offset(0.1, 0.72), 0.05, _fill(_sand));
  }

  @override
  bool shouldRepaint(covariant _CbtArtPainter old) => old.kind != kind;
}
