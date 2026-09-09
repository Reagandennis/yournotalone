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
    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(child: CustomPaint(painter: _TherapyArtPainter())),
    );
  }
}

class _TherapyArtPainter extends CustomPainter {
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
      Paint()..color = Brand.ink.withValues(alpha: 0.05),
    );

    // The warm wash behind them — the yellow pillar, out of focus.
    canvas.drawCircle(
      Offset(centre, h * 0.42),
      h * 0.46,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Brand.yellow.withValues(alpha: 0.22),
                Brand.yellow.withValues(alpha: 0),
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
      Brand.blue,
      -0.06,
    );

    // The person being listened to: a little smaller, leaning in.
    _figure(
      canvas,
      Offset(centre - unit * 1.35, baseline),
      h * 0.38,
      unit * 1.45,
      Brand.red,
      0.10,
    );

  }

  @override
  bool shouldRepaint(_TherapyArtPainter oldDelegate) => false;
}

/// The smaller mark used once a session is booked: the logo's four
/// pillars, standing.
class TherapyBookedArt extends StatelessWidget {
  const TherapyBookedArt({super.key, this.size = 78});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: RepaintBoundary(child: CustomPaint(painter: _BookedPainter())),
    );
  }
}

class _BookedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = Brand.blue.withValues(alpha: 0.10),
    );

    // The logo itself: four upright pillars, the middle pair taller.
    final barWidth = radius * 0.17;
    final gap = barWidth * 0.75;
    final totalWidth = Brand.pillarColors.length * barWidth + 3 * gap;
    var x = centre.dx - totalWidth / 2;
    for (var i = 0; i < Brand.pillarColors.length; i++) {
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
        Paint()..color = Brand.pillarColors[i],
      );
      x += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(_BookedPainter oldDelegate) => false;
}
