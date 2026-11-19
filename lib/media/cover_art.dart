import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../backgrounds/background_spec.dart';
import '../backgrounds/calm_visuals.dart';
import '../backgrounds/scene_background.dart';
import '../backgrounds/scene_library.dart';
import '../backgrounds/scene_painters.dart';
import '../brand.dart';
import '../discover/content_index.dart';

/// The picture the lock screen and the notification show for a sound or a
/// meditation.
///
/// The app's art is drawn in code rather than shipped as images, so this
/// is too: the item's own background, held still, behind its icon in its
/// colour, with the four pillars underneath — the same scene the person
/// sees on the item's screen. Drawn once per look and kept as a PNG in the
/// cache folder, since the lock screen can only take a file.
abstract final class CoverArt {
  /// Pixels on each side; enough for the largest lock-screen artwork.
  static const size = 512;

  /// Raise when the drawing changes, so cached pictures are redrawn.
  static const _version = 1;

  /// Off in widget tests, which have no folder or platform to hand it to.
  @visibleForTesting
  static bool enabled = !Platform.environment.containsKey('FLUTTER_TEST');

  /// Where the pictures are kept.
  @visibleForTesting
  static Future<Directory> Function() directory = getApplicationCacheDirectory;

  static final _drawn = <String, Uri>{};

  /// A `file:` link to [itemId]'s picture, drawn if need be; null if it
  /// can't be (the item then shows without one).
  ///
  /// Call it while the app is on screen: drawing needs the GPU, which iOS
  /// takes away from an app in the background.
  static Future<Uri?> forItem({
    required String itemId,
    required ContentKind kind,
    required IconData icon,
    required Color accent,
  }) async {
    if (!enabled) return null;
    try {
      final spec = SceneLibrary.instance.backgroundFor(
        itemId,
        kind,
        choice: CalmVisualsSetting.instance.choiceFor(itemId),
      );
      final key = keyFor(
        itemId: itemId,
        backgroundId: spec.id,
        icon: icon,
        accent: accent,
      );
      final known = _drawn[key];
      if (known != null && File.fromUri(known).existsSync()) return known;
      final folder = Directory('${(await directory()).path}/now_playing');
      final file = File('${folder.path}/$key.png');
      if (!file.existsSync()) {
        final png = await render(spec: spec, icon: icon, accent: accent);
        await folder.create(recursive: true);
        // Written aside and moved, so the lock screen never reads half.
        final part = File('${file.path}.part');
        await part.writeAsBytes(png, flush: true);
        await part.rename(file.path);
      }
      return _drawn[key] = file.uri;
    } catch (e) {
      debugPrint('Cover art unavailable for $itemId: $e');
      return null;
    }
  }

  /// The file name for a picture: everything that changes how it looks.
  /// The lock screen caches artwork by its path, so a different look must
  /// be a different file.
  @visibleForTesting
  static String keyFor({
    required String itemId,
    required String backgroundId,
    required IconData icon,
    required Color accent,
  }) {
    final parts = [
      _version,
      itemId,
      backgroundId,
      icon.fontFamily,
      icon.fontPackage,
      icon.codePoint,
      accent.toARGB32(),
    ].join('|');
    return sha1.convert(utf8.encode(parts)).toString().substring(0, 20);
  }

  /// Draws the picture as a PNG, in the light palette: the lock screen
  /// doesn't follow the app's dark mode.
  static Future<Uint8List> render({
    required BackgroundSpec spec,
    required IconData icon,
    required Color accent,
    int size = size,
  }) async {
    const c = BrandColors.light;
    final s = size.toDouble();
    final area = Offset.zero & Size(s, s);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, area);

    canvas.drawRect(area, Paint()..color = c.background);
    // The item's scene, held still. The painters draw faintly so text on
    // a screen stays readable; with nothing on top here, it can show.
    ScenePainter.of(
      spec,
      resolvePalette(c, spec.palette),
      SceneClock(sceneStillTime),
      intensity: 2.5,
    ).paint(canvas, area.size);

    final center = Offset(s / 2, s * 0.46);
    final radius = s * 0.25;
    final tint = c.accent(accent);
    // A soft glow of the item's colour around the disc.
    canvas.drawCircle(
      center,
      radius * 1.9,
      Paint()
        ..shader = ui.Gradient.radial(center, radius * 1.9, [
          accent.withValues(alpha: 0.22),
          accent.withValues(alpha: 0),
        ]),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.94),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = c.tint(accent, 0.35),
    );
    final glyph = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: radius * 1.05,
          color: tint,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
    glyph.dispose();

    // The four pillars, as under every title in the app.
    final bar = s * 0.022;
    final gap = bar * 0.8;
    final stripe = s * 0.30;
    final each = (stripe - gap * 3) / 4;
    var x = (s - stripe) / 2;
    final y = s * 0.84;
    for (final color in c.pillars) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, each, bar),
          Radius.circular(bar / 2),
        ),
        Paint()..color = color,
      );
      x += each + gap;
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    picture.dispose();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
