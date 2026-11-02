import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'background_spec.dart';

const _tau = math.pi * 2;

/// Where a scene is in time. [SceneBackground] advances it (at most 30
/// times a second); painters repaint off it without a widget rebuild.
class SceneClock extends ChangeNotifier {
  SceneClock([this.time = 0]);

  /// Seconds since the scene began, before [BackgroundSpec.speed].
  double time;

  /// 0–1 breathing swell, when the screen supplies one.
  double swell = 0;

  void tick(double time, double swell) {
    this.time = time;
    this.swell = swell;
    notifyListeners();
  }
}

/// The engines. Each is built once per background, colour set and
/// intensity, works out its layout up front from the seed, and then only
/// does arithmetic each frame: Paints, Paths and shaders are reused.
///
/// They draw faint colour over whatever is behind them (the page), never
/// an opaque fill, so text on top stays readable in light and dark mode.
abstract class ScenePainter extends CustomPainter {
  ScenePainter(this.spec, this.colors, this.clock, this.intensity)
    : super(repaint: clock);

  factory ScenePainter.of(
    BackgroundSpec spec,
    List<Color> colors,
    SceneClock clock, {
    double intensity = 1,
  }) => switch (spec.engine) {
    SceneEngine.waves => _WavesPainter(spec, colors, clock, intensity),
    SceneEngine.aurora => _AuroraPainter(spec, colors, clock, intensity),
    SceneEngine.particles => _ParticlesPainter(spec, colors, clock, intensity),
    SceneEngine.gradient => _GradientPainter(spec, colors, clock, intensity),
  };

  final BackgroundSpec spec;

  /// [BackgroundSpec.palette] resolved for the mode (see [resolvePalette]);
  /// each colour's alpha is its weight.
  final List<Color> colors;
  final SceneClock clock;
  final double intensity;

  /// How present the scene is: the spec's own intensity times the
  /// screen's.
  double get strength => spec.intensity * intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    paintScene(canvas, size, clock.time * spec.speed, clock.swell);
  }

  /// [t] is in scene seconds (already scaled by speed).
  void paintScene(Canvas canvas, Size size, double t, double swell);

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.runtimeType != runtimeType ||
      old.spec != spec ||
      old.clock != clock ||
      old.intensity != intensity ||
      !listEquals(old.colors, colors);
}

/// Layered swells along the lower half: one band per colour, the back
/// ones higher and fainter, neighbours drifting in opposite directions.
class _WavesPainter extends ScenePainter {
  _WavesPainter(super.spec, super.colors, super.clock, super.intensity) {
    final r = math.Random(spec.seed);
    _phases = [for (final _ in colors) r.nextDouble() * _tau];
    _paths = [for (final _ in colors) Path()];
  }

  late final List<double> _phases;
  late final List<Path> _paths;
  final _paint = Paint()..style = PaintingStyle.fill;

  @override
  void paintScene(Canvas canvas, Size size, double t, double swell) {
    final n = colors.length;
    final step = math.max(size.width / 40, 4.0);
    for (var i = 0; i < n; i++) {
      final depth = n == 1 ? 1.0 : i / (n - 1); // 0 at the back
      final base = size.height * (0.52 + 0.26 * depth - 0.03 * swell);
      final amp = size.height * (0.026 + 0.014 * depth);
      final k = _tau * spec.density * (0.9 + 0.35 * i) / size.width;
      final phase = _phases[i] + t * 0.32 * (i.isEven ? 1 : -0.8);
      final path = _paths[i]
        ..reset()
        ..moveTo(0, size.height);
      for (double x = 0; x < size.width + step; x += step) {
        final y =
            base +
            amp * math.sin(k * x + phase) +
            amp * 0.45 * math.sin(k * 1.9 * x - phase * 1.3 + i);
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width + step, size.height)
        ..close();
      final c = colors[i];
      _paint.color = c.withValues(
        alpha: c.a * (0.07 + 0.06 * depth) * strength,
      );
      canvas.drawPath(path, _paint);
    }
  }
}

/// Soft ribbons of light across the upper sky, each one wavering in
/// height and thickness, faded at both edges by a gradient.
class _AuroraPainter extends ScenePainter {
  _AuroraPainter(super.spec, super.colors, super.clock, super.intensity) {
    final r = math.Random(spec.seed);
    _phases = [for (final _ in colors) r.nextDouble() * _tau];
    _paths = [for (final _ in colors) Path()];
  }

  static const _steps = 36;

  late final List<double> _phases;
  late final List<Path> _paths;
  final _bottoms = Float64List(_steps + 1);
  final _paint = Paint()..style = PaintingStyle.fill;

  /// One vertical fade per ribbon, made for [_shaderSize].
  List<Shader>? _shaders;
  Size? _shaderSize;

  double _centre(int i, Size size) => size.height * (0.16 + 0.11 * i);
  double _sway(Size size) => size.height * 0.05;
  double _thickness(Size size) =>
      size.height * (0.06 + 0.03 * spec.density.clamp(0.2, 3.0));

  List<Shader> _shadersFor(Size size) {
    if (_shaders != null && _shaderSize == size) return _shaders!;
    _shaderSize = size;
    return _shaders = [
      for (var i = 0; i < colors.length; i++)
        () {
          final c = colors[i];
          final peak = c.a * 0.16 * strength;
          final reach = _sway(size) + _thickness(size) * 1.5;
          final centre = _centre(i, size);
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.withValues(alpha: 0),
              c.withValues(alpha: peak),
              c.withValues(alpha: peak * 0.5),
              c.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 0.65, 1],
          ).createShader(
            Rect.fromLTRB(0, centre - reach, size.width, centre + reach),
          );
        }(),
    ];
  }

  @override
  void paintScene(Canvas canvas, Size size, double t, double swell) {
    final shaders = _shadersFor(size);
    final sway = _sway(size);
    final thick = _thickness(size) * (1 + 0.15 * swell);
    for (var i = 0; i < colors.length; i++) {
      final ph = _phases[i];
      final dir = i.isEven ? 1.0 : -1.0;
      final k1 = _tau * (0.6 + 0.25 * i) / size.width;
      final k2 = _tau * (1.3 + 0.2 * i) / size.width;
      final centre = _centre(i, size);
      final path = _paths[i]..reset();
      for (var s = 0; s <= _steps; s++) {
        final x = size.width * s / _steps;
        final y = centre + sway * math.sin(k1 * x + t * 0.22 * dir + ph);
        final h = thick * (1 + 0.5 * math.sin(k2 * x - t * 0.17 + ph * 2));
        if (s == 0) {
          path.moveTo(x, y - h);
        } else {
          path.lineTo(x, y - h);
        }
        _bottoms[s] = y + h * 0.7;
      }
      for (var s = _steps; s >= 0; s--) {
        path.lineTo(size.width * s / _steps, _bottoms[s]);
      }
      path.close();
      _paint.shader = shaders[i];
      canvas.drawPath(path, _paint);
    }
  }
}

/// Small soft lights drifting slowly upward and swaying, each glowing
/// and fading on its own rhythm, faded out near the top and bottom.
class _ParticlesPainter extends ScenePainter {
  _ParticlesPainter(super.spec, super.colors, super.clock, super.intensity) {
    final r = math.Random(spec.seed);
    final n = (26 * spec.density).round().clamp(4, 90);
    double rand(double lo, double hi) => lo + r.nextDouble() * (hi - lo);
    _x = Float64List.fromList([for (var i = 0; i < n; i++) r.nextDouble()]);
    _y = Float64List.fromList([for (var i = 0; i < n; i++) r.nextDouble()]);
    _radius = Float64List.fromList([
      for (var i = 0; i < n; i++) rand(1.4, 3.6),
    ]);
    _rise = Float64List.fromList([
      for (var i = 0; i < n; i++) rand(0.006, 0.018),
    ]);
    _phase = Float64List.fromList([for (var i = 0; i < n; i++) rand(0, _tau)]);
    _glow = Float64List.fromList([for (var i = 0; i < n; i++) rand(0.3, 0.9)]);
    _colour = [for (var i = 0; i < n; i++) r.nextInt(colors.length)];
  }

  late final Float64List _x, _y, _radius, _rise, _phase, _glow;
  late final List<int> _colour;
  final _paint = Paint();

  @override
  void paintScene(Canvas canvas, Size size, double t, double swell) {
    final grow = 1 + 0.12 * swell;
    for (var i = 0; i < _x.length; i++) {
      final y = (_y[i] - t * _rise[i]) % 1.0;
      final x = _x[i] + 0.025 * math.sin(t * 0.3 * _glow[i] + _phase[i]);
      // Fade in at the bottom, out at the top, rather than pop.
      final edge = math.min(1.0, math.min(y, 1 - y) / 0.12);
      final pulse = 0.5 + 0.5 * math.sin(t * _glow[i] + _phase[i]);
      final c = colors[_colour[i]];
      final alpha = c.a * (0.16 + 0.22 * pulse) * edge * strength;
      final centre = Offset(x * size.width, y * size.height);
      final r = _radius[i] * grow;
      _paint.color = c.withValues(alpha: alpha * 0.22);
      canvas.drawCircle(centre, r * 3.2, _paint);
      _paint.color = c.withValues(alpha: alpha);
      canvas.drawCircle(centre, r, _paint);
    }
  }
}

/// Large, soft washes of colour drifting on a long cycle — one per
/// colour, side by side — like the logo pillars seen through frosted
/// glass. Each radial fade is made once around the origin and moved and
/// stretched with the canvas, so nothing is allocated per frame.
class _GradientPainter extends ScenePainter {
  _GradientPainter(super.spec, super.colors, super.clock, super.intensity) {
    final r = math.Random(spec.seed);
    final n = colors.length;
    _lanes = [
      for (var i = 0; i < n; i++) (i + 0.5) / n + (r.nextDouble() - 0.5) * 0.04,
    ];
    _rates = [for (final _ in colors) 0.55 + r.nextDouble() * 0.8];
    _phases = [for (final _ in colors) r.nextDouble()];
    _paints = [
      for (final c in colors)
        Paint()
          ..shader = RadialGradient(
            colors: [
              c.withValues(alpha: c.a * 0.20 * strength),
              c.withValues(alpha: c.a * 0.10 * strength),
              c.withValues(alpha: 0),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1)),
    ];
  }

  /// Long enough that the eye never catches the loop.
  static const _cycleSeconds = 48.0;
  static const _unit = Rect.fromLTRB(-1, -1, 1, 1);

  late final List<double> _lanes, _rates, _phases;
  late final List<Paint> _paints;

  @override
  void paintScene(Canvas canvas, Size size, double t, double swell) {
    final n = colors.length;
    final cycle = t / _cycleSeconds;
    final spread = 0.7 + 0.3 * spec.density.clamp(0.2, 3.0);
    for (var i = 0; i < n; i++) {
      final drift = math.sin(_tau * (cycle * _rates[i] + _phases[i]));
      final bob = math.cos(_tau * (cycle * _rates[i] * 0.6 + _phases[i]));
      final halfWidth = size.width * 0.68 / n * spread * (1 + 0.06 * drift);
      final halfHeight = size.height * 0.5 * (0.95 + 0.10 * bob + 0.16 * swell);
      canvas
        ..save()
        ..translate(
          size.width * (_lanes[i] + drift * 0.05),
          size.height * (0.46 + bob * 0.06 + swell * 0.04),
        )
        ..scale(halfWidth, halfHeight)
        ..drawRect(_unit, _paints[i])
        ..restore();
    }
  }
}
