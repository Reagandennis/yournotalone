import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../brand.dart';

/// The sunrise picture, and where its sun sits on the horizon as a
/// fraction of the image.
const _image = 'assets/rhythm/sunrise.jpg';
const _imageAspect = 4000 / 2182;
const _sunAt = Offset(0.523, 0.6);

/// How the picture is cropped into a short, wide card: centred, so the sun
/// and the horizon always stay in view.
const _alignment = Alignment.center;

/// The week's sunrise: the picture under a pre-dawn veil that lifts with
/// [progress] — deep dusk with stars at 0, the full warm morning at 1.
/// The lift is eased whenever [progress] changes; reduced motion skips it.
class SunriseArt extends StatelessWidget {
  const SunriseArt({
    super.key,
    required this.progress,
    this.height = 132,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(18)),
  });

  final double progress;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final dark = context.brand.isDark;
    final still = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              _image,
              fit: BoxFit.cover,
              alignment: _alignment,
              // Decoded no larger than it's shown.
              cacheWidth: 1200,
              excludeFromSemantics: true,
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: progress.clamp(0.0, 1.0)),
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 1600),
              curve: Curves.easeOutCubic,
              builder: (context, rise, _) => CustomPaint(
                painter: _DawnVeilPainter(rise: rise, dark: dark),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DawnVeilPainter extends CustomPainter {
  _DawnVeilPainter({required this.rise, required this.dark});

  final double rise;
  final bool dark;

  /// Where the picture's sun lands on the card, after the cover crop.
  Offset _sun(Size size) {
    final scale = math.max(size.width / _imageAspect, size.height);
    final shown = Size(scale * _imageAspect, scale);
    final left = (size.width - shown.width) / 2 * (1 + _alignment.x);
    final top = (size.height - shown.height) / 2 * (1 + _alignment.y);
    return Offset(
      left + shown.width * _sunAt.dx,
      top + shown.height * _sunAt.dy,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;
    final night = 1 - rise;
    final sun = _sun(size);

    // The veil: deep indigo at the top, dusky violet towards the horizon,
    // thinning as the week goes on.
    if (night > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, h),
            [
              const Color(0xFF0E1838).withValues(alpha: 0.82 * night),
              const Color(0xFF3A2D63).withValues(alpha: 0.66 * night),
              const Color(0xFF1A1E45).withValues(alpha: 0.72 * night),
            ],
            [0, (sun.dy / h).clamp(0.0, 1.0), 1],
          ),
      );

      // A first warmth on the horizon, even before the week has begun.
      canvas.drawCircle(
        sun,
        w * 0.4,
        Paint()
          ..shader = ui.Gradient.radial(sun, w * 0.4, [
            const Color(0xFFFF9E6B).withValues(alpha: 0.35 * night),
            const Color(0x00FF9E6B),
          ]),
      );

      // Stars, fading as the light comes.
      final starAlpha = (1 - rise * 1.8).clamp(0.0, 1.0);
      if (starAlpha > 0) {
        final random = math.Random(7);
        final star = Paint();
        for (var i = 0; i < 26; i++) {
          final x = random.nextDouble() * w;
          final y = random.nextDouble() * sun.dy * 0.7;
          star.color = Colors.white.withValues(
            alpha: starAlpha * (0.35 + 0.55 * random.nextDouble()),
          );
          canvas.drawCircle(
            Offset(x, y),
            0.6 + random.nextDouble() * 0.9,
            star,
          );
        }
      }
    }

    // Once the goal is near, the sun glows out over the scene.
    final glow = ((rise - 0.5) / 0.5).clamp(0.0, 1.0);
    if (glow > 0) {
      canvas.drawCircle(
        sun,
        w * 0.35,
        Paint()
          ..shader = ui.Gradient.radial(sun, w * 0.35, [
            const Color(0xFFFFE3A0).withValues(alpha: 0.4 * glow),
            const Color(0x00FFE3A0),
          ]),
      );
    }

    // A touch less light in dark mode, so the card doesn't glare.
    if (dark) {
      canvas.drawRect(rect, Paint()..color = const Color(0x24000000));
    }
  }

  @override
  bool shouldRepaint(_DawnVeilPainter old) =>
      old.rise != rise || old.dark != dark;
}

/// A small sun for a week in the history: full when the goal was met,
/// partly lit when some days were, a quiet dot when none were.
class WeekSun extends StatelessWidget {
  const WeekSun({super.key, required this.fill, this.size = 20});

  /// 0–1: how much of the goal that week reached.
  final double fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WeekSunPainter(fill, c)),
    );
  }
}

class _WeekSunPainter extends CustomPainter {
  _WeekSunPainter(this.fill, this.c);

  final double fill;
  final BrandColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (fill <= 0) {
      canvas.drawCircle(centre, r * 0.22, Paint()..color = c.border);
      return;
    }
    final gold = c.isDark ? const Color(0xFFFFC940) : const Color(0xFFF5A623);
    if (fill >= 1) {
      canvas.drawCircle(
        centre,
        r,
        Paint()
          ..shader = ui.Gradient.radial(centre, r, [
            gold.withValues(alpha: 0.35),
            gold.withValues(alpha: 0),
          ]),
      );
    }
    final disc = r * (0.4 + 0.25 * fill);
    canvas.drawCircle(
      centre,
      disc,
      Paint()..color = gold.withValues(alpha: 0.35 + 0.65 * fill),
    );
  }

  @override
  bool shouldRepaint(_WeekSunPainter old) => old.fill != fill || old.c != c;
}
