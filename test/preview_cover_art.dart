// Draws the lock-screen pictures for a few items, to look at. Not a test:
// the name keeps it out of `flutter test`'s default run. Run with:
//   flutter test test/preview_cover_art.dart
// The pictures land in build/cover_art/.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/backgrounds/scene_library.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/media/cover_art.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';

Future<void> _icons() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer))))
      .load();
}

void main() {
  testWidgets('cover art previews', (tester) async {
    await tester.runAsync(() async {
      await _icons();
      await SceneLibrary.instance.load();
      final out = Directory('build/cover_art')..createSync(recursive: true);
      final items = [
        for (final m in meditations.take(4))
          (m.id, ContentKind.meditation, m.icon, m.accent),
        for (final s in soundsCatalog.where(
          (s) =>
              {'Deep focus', 'Rainfall', 'Crickets at night'}.contains(s.title),
        ))
          (s.id, ContentKind.sound, s.icon, s.category.accent),
      ];
      for (final (id, kind, icon, accent) in items) {
        final png = await CoverArt.render(
          spec: SceneLibrary.instance.backgroundFor(id, kind),
          icon: icon,
          accent: accent,
        );
        final name = id.replaceAll(RegExp('[^A-Za-z]+'), '_');
        File('${out.path}/$name.png').writeAsBytesSync(png);
      }
    });
  });
}
