import 'package:flutter/material.dart';

import '../brand.dart';
import '../discover/content_index.dart';

/// The code-drawn scenes this build can paint. A background in content
/// names one and tunes it with [BackgroundSpec]'s parameters, so a new
/// background is a YAML file, not a download.
///
/// A Lottie background would be another engine (its file published like
/// audio); a build that doesn't know an engine leaves that background out.
enum SceneEngine { waves, aurora, particles, gradient }

/// One background from the catalogue: an engine and how to draw it.
@immutable
class BackgroundSpec {
  const BackgroundSpec({
    required this.id,
    required this.engine,
    required this.palette,
    this.speed = 1,
    this.density = 1,
    this.seed = 0,
    this.intensity = 1,
    this.defaultFor = const {},
    this.titles = const {},
  });

  /// Null for a background this build can't draw (an engine it doesn't
  /// know, a field it can't read), so one bad entry never costs the rest
  /// of the catalogue.
  static BackgroundSpec? fromJson(Map<String, dynamic> json) {
    try {
      final engine = SceneEngine.values.asNameMap()[json['engine']];
      if (engine == null) return null;
      final params = json['params'] as Map<String, dynamic>;
      final kinds = ContentKind.values.asNameMap();
      return BackgroundSpec(
        id: json['id'] as String,
        engine: engine,
        palette: [
          for (final hex in params['palette'] as List)
            Color(
              0xFF000000 | int.parse((hex as String).substring(1), radix: 16),
            ),
        ],
        speed: (params['speed'] as num).toDouble(),
        density: (params['density'] as num).toDouble(),
        seed: params['seed'] as int,
        intensity: (params['intensity'] as num?)?.toDouble() ?? 1,
        defaultFor: {
          for (final k in (json['defaultFor'] as List?) ?? const []) ?kinds[k],
        },
        titles: {
          for (final MapEntry(:key, :value)
              in (json['text'] as Map<String, dynamic>).entries)
            key: (value as Map<String, dynamic>)['title'] as String,
        },
      );
    } catch (e) {
      debugPrint('Background ${json['id']} unreadable: $e');
      return null;
    }
  }

  final String id;
  final SceneEngine engine;

  /// Back to front, as declared — [resolvePalette] turns them into what
  /// is drawn in the current mode.
  final List<Color> palette;

  /// 1 is the engine's usual pace and amount.
  final double speed;
  final double density;

  /// Places things differently, so two backgrounds on one engine differ.
  final int seed;

  /// 0–1, how present the whole scene is.
  final double intensity;

  /// Kinds that open with this background unless an item names its own.
  final Set<ContentKind> defaultFor;

  /// Title by locale.
  final Map<String, String> titles;

  String titleFor(String locale) => titles[locale] ?? titles['en'] ?? id;
}

/// What to draw before any catalogue has loaded, or if none has
/// backgrounds: the logo pillars as soft washes, the look sessions had
/// before backgrounds. Keep it in step with
/// `content/backgrounds/pillar-glow.yaml`.
const fallbackBackground = BackgroundSpec(
  id: 'pillar-glow',
  engine: SceneEngine.gradient,
  palette: [Pillars.red, Pillars.blue, Pillars.black, Pillars.yellow],
  defaultFor: {ContentKind.breathing},
  seed: 1,
  titles: {'en': 'Pillar glow'},
);

/// [palette] as drawn in the mode [c] is for: the lighter accents in the
/// dark, like the rest of the app's art. Near-black colours keep only a
/// third of their strength (in the dark they turn off-white), or they'd
/// read as a grey smudge — as the ink pillar does in the logo backdrop.
/// The weight travels in each colour's alpha.
List<Color> resolvePalette(BrandColors c, List<Color> palette) => [
  for (final p in palette)
    c.art(p).withValues(alpha: p.computeLuminance() < 0.03 ? 0.35 : 1),
];
