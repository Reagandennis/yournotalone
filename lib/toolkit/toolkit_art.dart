import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../brand.dart';

/// Which abstract composition to draw.
enum ToolkitArtKind {
  // CBT
  thoughts,
  traps,
  activity,
  worry,
  grounding,
  problem,
  learn,
  resources,
  // Sleep
  moon,
  diary,
  tomorrowList,
  awake,
  habits,
  windDown,
  // Stress
  gauge,
  circles,
  sigh,
  muscles,
  battery,
  pause,
}

/// Abstract, geometric illustrations for the CBT toolkit — the "shapes and
/// blobs" style of the reference design. Drawn in code, like [TherapyArt]:
/// they stay sharp at any size, weigh nothing, and carry no stock-image
/// licence. Each one is composed for a square [size] and is meant to sit
/// flush against the right edge of a card.
class ToolkitArt extends StatelessWidget {
  const ToolkitArt({super.key, required this.kind, this.size = 96});

  final ToolkitArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ToolkitArtPainter(kind, _paletteFor(context.brand)),
        ),
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

/// The colours an illustration is drawn in, for one mode. Resolved from
/// the theme in [ToolkitArt.build], since a painter can't read it; a
/// record, so two palettes compare by their colours.
typedef _Palette = ({
  Color red,
  Color blue,
  Color yellow,
  Color green,
  Color ink,
  Color peach,
  Color sky,
  Color sand,
  Color mint,
  Color stone,
  Color cut,
  Color mark,
});

_Palette _paletteFor(BrandColors c) {
  // On paper the soft tints are pillar colours mixed with white. On navy
  // they're the lightened pillar colours mixed into the page instead:
  // muted mid-tones that still stand off a dark card, and stay quieter
  // than the shapes beside them.
  Color soft(Color light, Color pillar) =>
      c.isDark ? Color.lerp(c.accent(pillar), c.background, 0.5)! : light;
  return (
    red: c.art(Pillars.red),
    blue: c.art(Pillars.blue),
    yellow: c.art(Pillars.yellow),
    green: c.art(_green),
    // Ink strokes and shapes on the page: off-white in the dark, like the
    // black pillar of the dark logo.
    ink: c.ink,
    peach: soft(_peach, Pillars.red),
    sky: soft(_sky, Pillars.blue),
    sand: soft(_sand, Pillars.yellow),
    mint: soft(_mint, _green),
    stone: soft(_stone, Pillars.black),
    // White cut-outs on a coloured shape: ruled lines, a tick. The shapes
    // lighten in the dark, so the cut-outs turn to the navy of the page.
    cut: c.isDark ? c.background : Colors.white,
    // Small ink marks on a bright shape, such as an eye on a pebble, stay
    // dark in both modes, like the face on a mood character.
    mark: c.isDark ? c.background : c.ink,
  );
}

class _ToolkitArtPainter extends CustomPainter {
  const _ToolkitArtPainter(this.kind, this.p);

  final ToolkitArtKind kind;
  final _Palette p;

  Paint _fill(Color colour) => Paint()
    ..color = colour
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    // Everything below works in a 0..1 square.
    canvas.scale(s);
    switch (kind) {
      case ToolkitArtKind.thoughts:
        _thoughts(canvas);
      case ToolkitArtKind.traps:
        _traps(canvas);
      case ToolkitArtKind.activity:
        _activity(canvas);
      case ToolkitArtKind.worry:
        _worry(canvas);
      case ToolkitArtKind.grounding:
        _grounding(canvas);
      case ToolkitArtKind.problem:
        _problem(canvas);
      case ToolkitArtKind.learn:
        _learn(canvas);
      case ToolkitArtKind.resources:
        _resources(canvas);
      case ToolkitArtKind.moon:
        _moon(canvas);
      case ToolkitArtKind.diary:
        _diary(canvas);
      case ToolkitArtKind.tomorrowList:
        _tomorrowList(canvas);
      case ToolkitArtKind.awake:
        _awake(canvas);
      case ToolkitArtKind.habits:
        _habits(canvas);
      case ToolkitArtKind.windDown:
        _windDown(canvas);
      case ToolkitArtKind.gauge:
        _gauge(canvas);
      case ToolkitArtKind.circles:
        _circles(canvas);
      case ToolkitArtKind.sigh:
        _sigh(canvas);
      case ToolkitArtKind.muscles:
        _muscles(canvas);
      case ToolkitArtKind.battery:
        _battery(canvas);
      case ToolkitArtKind.pause:
        _pause(canvas);
    }
  }

  /// A four-point spark, the toolkit's star.
  Path _spark(double cx, double cy, double r, [double pinch = 0.28]) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final d = i.isEven ? r : r * pinch;
      final p = Offset(cx + math.cos(a) * d, cy + math.sin(a) * d);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // ── Sleep ────────────────────────────────────────────────────────

  /// A crescent over a dark hill, two small stars keeping it company.
  void _moon(Canvas c) {
    c.drawOval(const Rect.fromLTWH(0.2, 0.74, 1.1, 0.7), _fill(p.blue));
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(
        Rect.fromCircle(center: const Offset(0.6, 0.42), radius: 0.3),
      ),
      Path()..addOval(
        Rect.fromCircle(center: const Offset(0.72, 0.34), radius: 0.27),
      ),
    );
    c.drawPath(moon, _fill(p.yellow));
    c.drawPath(_spark(0.18, 0.22, 0.09), _fill(p.sand));
    c.drawPath(_spark(0.9, 0.62, 0.06), _fill(p.peach));
    c.drawCircle(const Offset(0.3, 0.5), 0.035, _fill(p.sky));
  }

  /// A notebook with ruled lines and a moon in the corner: last night,
  /// written down.
  void _diary(Canvas c) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.34, 0.16, 0.7, 0.92),
        const Radius.circular(0.08),
      ),
      _fill(p.blue),
    );
    c.drawRect(const Rect.fromLTWH(0.34, 0.16, 0.1, 0.92), _fill(p.sky));
    final line = Paint()
      ..color = p.cut
      ..strokeWidth = 0.05
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final y = 0.36 + i * 0.16;
      c.drawLine(Offset(0.56, y), Offset(i == 3 ? 0.78 : 0.94, y), line);
    }
    c.drawCircle(const Offset(0.16, 0.3), 0.13, _fill(p.yellow));
    c.drawCircle(const Offset(0.12, 0.72), 0.05, _fill(p.red));
  }

  /// Three ticked rows on a card: tomorrow, already handled.
  void _tomorrowList(Canvas c) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.24, 0.1, 0.9, 0.9),
        const Radius.circular(0.1),
      ),
      _fill(p.peach),
    );
    final colours = [p.red, p.blue, p.yellow];
    final line = Paint()
      ..color = p.cut
      ..strokeWidth = 0.06
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = 0.3 + i * 0.24;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0.36, y - 0.07, 0.14, 0.14),
          const Radius.circular(0.03),
        ),
        _fill(colours[i]),
      );
      c.drawLine(Offset(0.6, y), Offset(i == 1 ? 0.8 : 1.0, y), line);
    }
    c.drawCircle(const Offset(0.12, 0.84), 0.09, _fill(p.ink));
  }

  /// A figure up in the small hours, a lamp glowing low beside them.
  void _awake(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0.62, 0.0, 0.5, 1.1), _fill(p.sky));
    c.drawCircle(const Offset(0.82, 0.3), 0.2, _fill(p.sand));
    c.drawCircle(const Offset(0.82, 0.3), 0.1, _fill(p.yellow));
    c.drawRect(const Rect.fromLTWH(0.8, 0.4, 0.04, 0.4), _fill(p.ink));
    // The person: a pillar body and a round head, like the logo bars.
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.24, 0.44, 0.22, 0.66),
        const Radius.circular(0.11),
      ),
      _fill(p.ink),
    );
    c.drawCircle(const Offset(0.35, 0.3), 0.12, _fill(p.ink));
    c.drawCircle(const Offset(0.1, 0.16), 0.05, _fill(p.red));
  }

  /// Three habit tiles, one already ticked.
  void _habits(Canvas c) {
    void tile(double x, double y, Color colour) => c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 0.36, 0.36),
        const Radius.circular(0.08),
      ),
      _fill(colour),
    );
    tile(0.56, 0.06, p.yellow);
    tile(0.3, 0.36, p.blue);
    tile(0.6, 0.66, p.green);
    final tick = Paint()
      ..color = p.cut
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
      Path()
        ..moveTo(0.69, 0.84)
        ..lineTo(0.76, 0.91)
        ..lineTo(0.88, 0.76),
      tick,
    );
    c.drawCircle(const Offset(0.14, 0.2), 0.07, _fill(p.red));
  }

  /// The sun going down behind a blue horizon: lights dimming on purpose.
  void _windDown(Canvas c) {
    c.drawCircle(const Offset(0.62, 0.6), 0.44, _fill(p.sand));
    c.drawCircle(const Offset(0.62, 0.6), 0.27, _fill(p.yellow));
    c.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(0.1, 0.62, 1.1, 0.5),
        topLeft: const Radius.circular(0.16),
      ),
      _fill(p.blue),
    );
    c.drawOval(const Rect.fromLTWH(0.66, 0.72, 0.5, 0.36), _fill(p.sky));
    c.drawCircle(const Offset(0.14, 0.24), 0.06, _fill(p.red));
  }

  // ── Stress ───────────────────────────────────────────────────────

  /// A dial with the needle sitting in the amber: how full is the tank.
  void _gauge(Canvas c) {
    const centre = Offset(0.6, 0.72);
    final track = Paint()
      ..color = p.stone
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.16
      ..strokeCap = StrokeCap.round;
    c.drawArc(
      Rect.fromCircle(center: centre, radius: 0.42),
      math.pi,
      math.pi,
      false,
      track,
    );
    c.drawArc(
      Rect.fromCircle(center: centre, radius: 0.42),
      math.pi,
      math.pi * 0.62,
      false,
      track..color = p.yellow,
    );
    c.drawArc(
      Rect.fromCircle(center: centre, radius: 0.42),
      math.pi * 1.62,
      math.pi * 0.16,
      false,
      track..color = p.red,
    );
    final needle = Paint()
      ..color = p.ink
      ..strokeWidth = 0.06
      ..strokeCap = StrokeCap.round;
    c.drawLine(centre, centre + const Offset(0.14, -0.34), needle);
    c.drawCircle(centre, 0.07, _fill(p.ink));
    c.drawRect(const Rect.fromLTWH(0.08, 0.14, 0.12, 0.12), _fill(p.blue));
  }

  /// Three rings — control, influence, everything else — with you in the
  /// middle.
  void _circles(Canvas c) {
    const centre = Offset(0.62, 0.58);
    c.drawCircle(centre, 0.46, _fill(p.sky));
    c.drawCircle(centre, 0.3, _fill(p.blue));
    c.drawCircle(centre, 0.14, _fill(p.yellow));
    c.drawCircle(centre, 0.05, _fill(p.mark));
    c.drawRect(const Rect.fromLTWH(0.06, 0.1, 0.12, 0.12), _fill(p.red));
    c.drawCircle(const Offset(0.14, 0.86), 0.06, _fill(p.peach));
  }

  /// Two short waves in and one long wave out.
  void _sigh(Canvas c) {
    c.drawCircle(const Offset(0.66, 0.56), 0.4, _fill(p.yellow));
    // The breath runs mostly over the yellow disc, so it keeps the logo's
    // blue in the dark too: the lightened blue fades against the yellow.
    final breath = Paint()
      ..color = Pillars.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.07
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0.1, 0.66)
      ..quadraticBezierTo(0.22, 0.32, 0.34, 0.5)
      ..quadraticBezierTo(0.44, 0.26, 0.54, 0.44)
      ..cubicTo(0.7, 0.7, 0.86, 0.92, 1.08, 0.84);
    c.drawPath(path, breath);
    c.drawCircle(const Offset(0.16, 0.2), 0.06, _fill(p.red));
    c.drawCircle(const Offset(0.92, 0.22), 0.05, _fill(p.sky));
  }

  /// Three bands, tight to loose: tense, then let go.
  void _muscles(Canvas c) {
    void band(double y, double w, Color colour) => c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.32, y, w, 0.2),
        const Radius.circular(0.1),
      ),
      _fill(colour),
    );
    band(0.12, 0.44, p.ink);
    band(0.42, 0.64, p.blue);
    band(0.72, 0.84, p.sand);
    // A pulse of tension leaving the top band.
    final zig = Paint()
      ..color = p.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(
      Path()
        ..moveTo(0.08, 0.3)
        ..lineTo(0.16, 0.16)
        ..lineTo(0.2, 0.28)
        ..lineTo(0.26, 0.12),
      zig,
    );
    c.drawCircle(const Offset(0.14, 0.62), 0.06, _fill(p.red));
  }

  /// A battery a third full, and the spark that refills it.
  void _battery(Canvas c) {
    final shell = Paint()
      ..color = p.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.07;
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.3, 0.3, 0.68, 0.4),
        const Radius.circular(0.1),
      ),
      shell,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.98, 0.42, 0.08, 0.16),
        const Radius.circular(0.03),
      ),
      _fill(p.ink),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.37, 0.37, 0.22, 0.26),
        const Radius.circular(0.05),
      ),
      _fill(p.yellow),
    );
    c.drawPath(_spark(0.18, 0.2, 0.14), _fill(p.green));
    c.drawCircle(const Offset(0.8, 0.88), 0.07, _fill(p.red));
    c.drawCircle(const Offset(0.16, 0.8), 0.05, _fill(p.sky));
  }

  /// A pause mark on a warm disc: permission to stop for a minute.
  void _pause(Canvas c) {
    c.drawCircle(const Offset(0.62, 0.56), 0.42, _fill(p.yellow));
    // The bars sit on the disc, not the page: the logo's blue in both
    // modes, as the lightened blue fades against the yellow.
    for (final x in [0.48, 0.66]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0.34, 0.12, 0.44),
          const Radius.circular(0.06),
        ),
        _fill(Pillars.blue),
      );
    }
    c.drawCircle(const Offset(0.12, 0.2), 0.07, _fill(p.red));
    c.drawCircle(const Offset(0.14, 0.86), 0.05, _fill(p.stone));
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
      _fill(p.yellow),
    );
    c.drawCircle(const Offset(0.5, 0.5), 0.06, _fill(p.peach));
    c.drawCircle(const Offset(0.36, 0.36), 0.09, _fill(p.peach));
    c.drawCircle(const Offset(0.5, 0.17), 0.16, _fill(p.red));
    c.drawRect(const Rect.fromLTWH(0.82, 0.3, 0.14, 0.14), _fill(p.blue));
  }

  /// Arcs curling inward with a small red dot caught in the middle — the
  /// pull of a thinking trap.
  void _traps(Canvas c) {
    final stroke = Paint()
      ..color = p.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.11
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    const centre = Offset(0.56, 0.56);
    c.drawArc(
      Rect.fromCircle(center: centre, radius: 0.42),
      math.pi * 0.9,
      math.pi * 1.35,
      false,
      stroke,
    );
    c.drawArc(
      Rect.fromCircle(center: centre, radius: 0.24),
      math.pi * 0.3,
      math.pi * 1.3,
      false,
      stroke..color = p.sky,
    );
    c.drawCircle(centre, 0.08, _fill(p.red));
    final tri = Path()
      ..moveTo(0.06, 0.18)
      ..lineTo(0.3, 0.06)
      ..lineTo(0.26, 0.34)
      ..close();
    c.drawPath(tri, _fill(p.yellow));
  }

  /// A sun coming up over a hill: doing one small thing today.
  void _activity(Canvas c) {
    final rays = Paint()
      ..color = p.sand
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
    c.drawCircle(sun, 0.25, _fill(p.yellow));
    c.drawOval(const Rect.fromLTWH(0.1, 0.62, 1.1, 0.7), _fill(p.green));
    c.drawOval(const Rect.fromLTWH(-0.2, 0.74, 0.7, 0.5), _fill(p.mint));
    c.drawCircle(const Offset(0.16, 0.3), 0.07, _fill(p.red));
  }

  /// A clock face with a little cloud parked beside it: worry has a time
  /// and a place.
  void _worry(Canvas c) {
    const centre = Offset(0.62, 0.6);
    c.drawCircle(centre, 0.36, _fill(p.blue));
    c.drawCircle(centre, 0.28, _fill(p.sky));
    final hand = Paint()
      ..color = p.ink
      ..strokeWidth = 0.05
      ..strokeCap = StrokeCap.round;
    c.drawLine(centre, centre + const Offset(0, -0.2), hand);
    c.drawLine(centre, centre + const Offset(0.15, 0.08), hand);
    c.drawCircle(centre, 0.04, _fill(p.ink));
    // The cloud: three overlapping circles on a flat base.
    final cloud = _fill(p.stone);
    c.drawCircle(const Offset(0.18, 0.24), 0.11, cloud);
    c.drawCircle(const Offset(0.3, 0.18), 0.13, cloud);
    c.drawCircle(const Offset(0.4, 0.27), 0.09, cloud);
    c.drawRect(const Rect.fromLTWH(0.1, 0.24, 0.36, 0.12), cloud);
    c.drawCircle(const Offset(0.9, 0.16), 0.08, _fill(p.yellow));
  }

  /// Stacked pebbles — steady, and here. Modelled on the reference's
  /// "challenging times" card.
  void _grounding(Canvas c) {
    c.drawOval(const Rect.fromLTWH(0.1, 0.78, 0.86, 0.3), _fill(p.stone));
    c.drawOval(const Rect.fromLTWH(0.2, 0.46, 0.66, 0.42), _fill(p.yellow));
    c.drawOval(const Rect.fromLTWH(0.3, 0.22, 0.44, 0.3), _fill(p.sand));
    c.drawCircle(const Offset(0.52, 0.12), 0.11, _fill(p.ink));
    // A closed, resting eye on the big pebble.
    final eye = Paint()
      ..color = p.mark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.035
      ..strokeCap = StrokeCap.round;
    c.drawArc(
      const Rect.fromLTWH(0.4, 0.58, 0.26, 0.14),
      0.15 * math.pi,
      0.7 * math.pi,
      false,
      eye,
    );
    c.drawCircle(const Offset(0.1, 0.36), 0.06, _fill(p.blue));
  }

  /// A spark above a solid block: the moment a way through shows itself.
  void _problem(Canvas c) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.34, 0.62, 0.5, 0.5),
        const Radius.circular(0.1),
      ),
      _fill(p.blue),
    );
    c.drawRect(const Rect.fromLTWH(0.46, 0.5, 0.26, 0.14), _fill(p.sky));
    c.drawPath(_spark(0.58, 0.28, 0.26), _fill(p.yellow));
    c.drawCircle(const Offset(0.14, 0.7), 0.09, _fill(p.red));
    c.drawRect(const Rect.fromLTWH(0.9, 0.12, 0.1, 0.1), _fill(p.peach));
  }

  /// An open book: two leaning pages and a sun to read by.
  void _learn(Canvas c) {
    c.drawCircle(const Offset(0.28, 0.3), 0.2, _fill(p.yellow));
    c.save();
    c.translate(0.52, 0.98);
    c.rotate(-0.22);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-0.4, -0.46, 0.4, 0.5),
        const Radius.circular(0.05),
      ),
      _fill(p.red),
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
      _fill(p.peach),
    );
    c.restore();
    c.drawRect(const Rect.fromLTWH(0.49, 0.52, 0.06, 0.46), _fill(p.ink));
    c.drawCircle(const Offset(0.86, 0.22), 0.06, _fill(p.blue));
  }

  /// A signpost pointing onward: the good places to go next.
  void _resources(Canvas c) {
    c.drawArc(
      const Rect.fromLTWH(0.4, 0.4, 0.8, 0.8),
      math.pi,
      math.pi,
      true,
      _fill(p.red),
    );
    c.drawRect(const Rect.fromLTWH(0.3, 0.42, 0.08, 0.6), _fill(p.ink));
    final sign = Path()
      ..moveTo(0.14, 0.2)
      ..lineTo(0.6, 0.2)
      ..lineTo(0.72, 0.32)
      ..lineTo(0.6, 0.44)
      ..lineTo(0.14, 0.44)
      ..close();
    c.drawPath(sign, _fill(p.blue));
    c.drawCircle(const Offset(0.86, 0.14), 0.07, _fill(p.yellow));
    c.drawCircle(const Offset(0.1, 0.72), 0.05, _fill(p.sand));
  }

  @override
  bool shouldRepaint(covariant _ToolkitArtPainter old) =>
      old.kind != kind || old.p != p;
}
