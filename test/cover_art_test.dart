import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/backgrounds/scene_library.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/discover/content_index.dart';
import 'package:yournotalone/media/cover_art.dart';

/// Width and height from a PNG's header.
(int, int) _pngSize(Uint8List png) {
  expect(png.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final header = ByteData.sublistView(png, 16, 24);
  return (header.getUint32(0), header.getUint32(4));
}

void main() {
  test('a picture\'s file name follows everything that changes its look', () {
    String key({
      String item = 'meditation:Body scan',
      String background = 'night-aurora',
      IconData icon = Icons.spa_rounded,
      Color accent = Pillars.blue,
    }) => CoverArt.keyFor(
      itemId: item,
      backgroundId: background,
      icon: icon,
      accent: accent,
    );

    expect(key(), key());
    expect(key(background: 'dusk-waves'), isNot(key()));
    expect(key(accent: Pillars.yellow), isNot(key()));
    expect(key(icon: Icons.bedtime_rounded), isNot(key()));
    expect(key(item: 'sound:Rainfall'), isNot(key()));
  });

  testWidgets('draws a square PNG for the lock screen', (tester) async {
    final png = (await tester.runAsync(
      () => CoverArt.render(
        spec: SceneLibrary.instance.backgrounds.first,
        icon: Icons.spa_rounded,
        accent: Pillars.blue,
      ),
    ))!;
    expect(_pngSize(png), (CoverArt.size, CoverArt.size));
  });

  testWidgets('keeps the picture as a file and draws it once', (tester) async {
    final folder = Directory.systemTemp.createTempSync('cover_art');
    addTearDown(() => folder.deleteSync(recursive: true));
    CoverArt.enabled = true;
    CoverArt.directory = () async => folder;
    addTearDown(() => CoverArt.enabled = false);

    Future<Uri?> art() => CoverArt.forItem(
      itemId: 'sound:Rainfall',
      kind: ContentKind.sound,
      icon: Icons.water_drop_rounded,
      accent: Pillars.black,
    );

    final first = (await tester.runAsync(art))!;
    expect(first.isScheme('file'), isTrue);
    final file = File.fromUri(first);
    expect(_pngSize(file.readAsBytesSync()), (512, 512));
    final drawnAt = file.lastModifiedSync();

    final again = await tester.runAsync(art);
    expect(again, first);
    expect(file.lastModifiedSync(), drawnAt);
    // Nothing half-written left behind.
    expect(
      folder.listSync(recursive: true).where((f) => f.path.endsWith('.part')),
      isEmpty,
    );
  });
}
