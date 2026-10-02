import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../brand.dart';

/// Two people sitting with each other, drawn from the logo's pillars.
///
/// The brand is four coloured pillars; here two of them become figures,
/// one leaning slightly toward the other. Geometric rather than
/// illustrative on purpose: it is drawn in
/// code, so it stays sharp on every screen, weighs nothing, and carries no
/// stock-image licence.
class TherapyArt extends StatelessWidget {
  const TherapyArt({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _TherapyArtPainter(
            shadow: c.tint(Pillars.black, 0.05),
            glow: c.tint(Pillars.yellow, 0.22),
            listener: c.art(Pillars.blue),
            speaker: c.art(Pillars.red),
          ),
        ),
      ),
    );
  }
}

class _TherapyArtPainter extends CustomPainter {
  _TherapyArtPainter({
    required this.shadow,
    required this.glow,
    required this.listener,
    required this.speaker,
  });

  final Color shadow;
  final Color glow;
  final Color listener;
  final Color speaker;

  /// Draws one figure: a rounded pillar body and a circular head, tilted
  /// by [lean] radians toward the conversation.
  void _figure(
    Canvas canvas,
    Offset base,
    double bodyHeight,
    double bodyWidth,
    Color colour,
    double lean,
  ) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(lean);

    final paint = Paint()..color = colour;
    final headRadius = bodyWidth * 0.46;
    final gap = headRadius * 0.42;

    // Body: a pillar with fully rounded ends, exactly like the logo bars.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(-bodyWidth / 2, -bodyHeight, bodyWidth, bodyHeight),
      Radius.circular(bodyWidth / 2),
    );
    canvas.drawRRect(body, paint);

    // Head, floating just above the shoulders.
    canvas.drawCircle(
      Offset(0, -bodyHeight - gap - headRadius),
      headRadius,
      paint,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centre = w / 2;

    // A soft ground for them to sit on, so the figures aren't floating in
    // white space.
    final ground = Offset(centre, h * 0.93);
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: w * 0.34, height: h * 0.055),
      Paint()..color = shadow,
    );

    // The warm wash behind them — the yellow pillar, out of focus.
    canvas.drawCircle(
      Offset(centre, h * 0.42),
      h * 0.46,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                glow,
                glow.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(centre, h * 0.42),
                radius: h * 0.46,
              ),
            ),
    );

    final unit = h * 0.11;
    final baseline = h * 0.9;

    // The listener: taller, upright, steady.
    _figure(
      canvas,
      Offset(centre + unit * 1.35, baseline),
      h * 0.46,
      unit * 1.5,
      listener,
      -0.06,
    );

    // The person being listened to: a little smaller, leaning in.
    _figure(
      canvas,
      Offset(centre - unit * 1.35, baseline),
      h * 0.38,
      unit * 1.45,
      speaker,
      0.10,
    );

  }

  @override
  bool shouldRepaint(_TherapyArtPainter oldDelegate) =>
      oldDelegate.shadow != shadow ||
      oldDelegate.glow != glow ||
      oldDelegate.listener != listener ||
      oldDelegate.speaker != speaker;
}

/// The smaller mark used once a session is booked: the logo's four
/// pillars, standing.
class TherapyBookedArt extends StatelessWidget {
  const TherapyBookedArt({super.key, this.size = 78});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BookedPainter(
            disc: c.tint(Pillars.blue, 0.10),
            pillars: c.pillars,
          ),
        ),
      ),
    );
  }
}

class _BookedPainter extends CustomPainter {
  _BookedPainter({required this.disc, required this.pillars});

  final Color disc;

  /// In logo order: red, blue, black, yellow.
  final List<Color> pillars;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = disc,
    );

    // The logo itself: four upright pillars, the middle pair taller.
    final barWidth = radius * 0.17;
    final gap = barWidth * 0.75;
    final totalWidth = pillars.length * barWidth + 3 * gap;
    var x = centre.dx - totalWidth / 2;
    for (var i = 0; i < pillars.length; i++) {
      final tall = i == 1 || i == 2;
      final barHeight = radius * (tall ? 1.02 : 0.72);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            centre.dy + radius * 0.42 - barHeight,
            barWidth,
            barHeight,
          ),
          Radius.circular(barWidth / 2),
        ),
        Paint()..color = pillars[i],
      );
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_BookedPainter oldDelegate) =>
      oldDelegate.disc != disc || !listEquals(oldDelegate.pillars, pillars);
}
