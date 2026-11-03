import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yournotalone/backgrounds/background_spec.dart';
import 'package:yournotalone/backgrounds/battery_saver.dart';
import 'package:yournotalone/backgrounds/calm_visuals.dart';
import 'package:yournotalone/backgrounds/scene_background.dart';
import 'package:yournotalone/backgrounds/scene_library.dart';
import 'package:yournotalone/backgrounds/scene_painters.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/discover/content_index.dart';

CatalogSnapshot _bundled() => CatalogSnapshot.fromJson(
  jsonDecode(File(bundledCatalogAsset).readAsStringSync())
      as Map<String, dynamic>,
)!;

Map<String, dynamic> _spec({String engine = 'waves'}) => {
  'id': 'test-scene',
  'order': 10,
  'engine': engine,
  'defaultFor': ['sound', 'not-a-kind'],
  'params': {
    'palette': ['#3764CD', '#1A2238'],
    'speed': 0.8,
    'density': 1.2,
    'seed': 4,
  },
  'text': {
    'en': {'title': 'Test scene'},
    'fr': {'title': 'Scène'},
  },
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CalmVisualsSetting.instance.reset();
    SceneLibrary.instance.reset();
  });

  group('spec', () {
    test('reads an engine and its parameters', () {
      final spec = BackgroundSpec.fromJson(_spec())!;
      expect(spec.id, 'test-scene');
      expect(spec.engine, SceneEngine.waves);
      expect(spec.palette, const [Color(0xFF3764CD), Color(0xFF1A2238)]);
      expect(spec.speed, 0.8);
      expect(spec.density, 1.2);
      expect(spec.seed, 4);
      expect(spec.intensity, 1);
      // A kind this build doesn't know is dropped, not fatal.
      expect(spec.defaultFor, {ContentKind.sound});
      expect(spec.titleFor('fr'), 'Scène');
      expect(spec.titleFor('de'), 'Test scene');
    });

    test('skips an engine this build can\'t draw, or a broken entry', () {
      expect(BackgroundSpec.fromJson(_spec(engine: 'lottie')), isNull);
      expect(BackgroundSpec.fromJson({..._spec(), 'params': 'nope'}), isNull);

      final json =
          jsonDecode(File(bundledCatalogAsset).readAsStringSync())
              as Map<String, dynamic>;
      final snapshot = CatalogSnapshot.fromJson({
        ...json,
        'backgrounds': [
          _spec(engine: 'lottie'),
          {'id': 'broken'},
          _spec(),
        ],
      })!;
      expect([for (final b in snapshot.backgrounds) b.id], ['test-scene']);
    });

    test('every shipped background can be drawn by this build', () {
      final raw =
          jsonDecode(File(bundledCatalogAsset).readAsStringSync())
              as Map<String, dynamic>;
      final snapshot = _bundled();
      expect(
        snapshot.backgrounds,
        hasLength((raw['backgrounds'] as List).length),
      );
      expect(snapshot.backgrounds.length, inInclusiveRange(4, 6));
      expect({
        for (final b in snapshot.backgrounds) b.engine,
      }, SceneEngine.values.toSet());
      final crickets = snapshot.items.firstWhere(
        (i) => i.id == 'sound:Crickets at night',
      );
      expect(crickets.background, 'fireflies');
    });

    test('the built-in fallback matches pillar-glow in content', () {
      final glow = _bundled().backgrounds.firstWhere(
        (b) => b.id == fallbackBackground.id,
      );
      expect(glow.engine, fallbackBackground.engine);
      expect(glow.palette, fallbackBackground.palette);
      expect(glow.speed, fallbackBackground.speed);
      expect(glow.density, fallbackBackground.density);
      expect(glow.seed, fallbackBackground.seed);
      expect(glow.defaultFor, fallbackBackground.defaultFor);
    });
  });

  group('library', () {
    test('has the fallback before any catalogue loads', () {
      final library = SceneLibrary.instance;
      expect(library.backgrounds, [fallbackBackground]);
      expect(
        library.backgroundFor('sound:Rainfall', ContentKind.sound),
        fallbackBackground,
      );
    });

    test('picks the choice, then the item\'s own, then the kind\'s', () {
      final library = SceneLibrary.instance..use(_bundled());
      String pick(String id, ContentKind kind, [String? choice]) =>
          library.backgroundFor(id, kind, choice: choice).id;

      expect(pick('sound:Crickets at night', ContentKind.sound), 'fireflies');
      expect(pick('sound:White noise', ContentKind.sound), 'dusk-waves');
      expect(
        pick('breathing:Box breathing', ContentKind.breathing),
        'pillar-glow',
      );
      expect(
        pick('meditation:Body scan', ContentKind.meditation),
        'night-aurora',
      );
      expect(
        pick('sound:White noise', ContentKind.sound, 'morning-mist'),
        'morning-mist',
      );
      // A pick that's no longer offered falls back quietly.
      expect(
        pick('sound:Crickets at night', ContentKind.sound, 'gone'),
        'fireflies',
      );
    });
  });

  group('calm visuals setting', () {
    test('is kept between launches', () async {
      final setting = CalmVisualsSetting.instance;
      await setting.load();
      expect(setting.enabled, isTrue);
      expect(setting.choiceFor('sound:Rainfall'), isNull);

      await setting.setEnabled(false);
      await setting.choose('sound:Rainfall', 'fireflies');
      setting.reset();
      await setting.load();
      expect(setting.enabled, isFalse);
      expect(setting.choiceFor('sound:Rainfall'), 'fireflies');

      await setting.choose('sound:Rainfall', null);
      setting.reset();
      await setting.load();
      expect(setting.choiceFor('sound:Rainfall'), isNull);
    });
  });

  group('engines', () {
    test('paint every shipped background without throwing', () {
      final backgrounds = [..._bundled().backgrounds, fallbackBackground];
      for (final colors in [BrandColors.light, BrandColors.dark]) {
        for (final spec in backgrounds) {
          for (final size in const [Size(390, 844), Size(84, 104), Size.zero]) {
            for (final (time, swell) in const [
              (0.0, 0.0),
              (12.0, 0.5),
              (3600.0, 1.0),
            ]) {
              final clock = SceneClock(time)..swell = swell;
              final painter = ScenePainter.of(
                spec,
                resolvePalette(colors, spec.palette),
                clock,
                intensity: 0.7,
              );
              final recorder = ui.PictureRecorder();
              painter.paint(Canvas(recorder), size);
              recorder.endRecording().dispose();
              clock.dispose();
            }
          }
        }
      }
    });
  });

  group('scene', () {
    Widget scene({bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const SceneBackground(spec: fallbackBackground),
      ),
    );

    ScenePainter painterOf(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(SceneBackground),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as ScenePainter;

    testWidgets('moves at no more than 30 fps', (tester) async {
      await tester.pumpWidget(scene());
      final clock = painterOf(tester).clock;
      var frames = 0;
      clock.addListener(() => frames++);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(microseconds: 16667));
      }
      expect(frames, inInclusiveRange(28, 31));
      expect(clock.time, greaterThan(sceneStillTime));
    });

    testWidgets('reduce motion draws one still frame', (tester) async {
      await tester.pumpWidget(scene(reduceMotion: true));
      expect(find.byType(CustomPaint), findsWidgets);
      // No ticker: nothing asks for another frame.
      expect(tester.binding.transientCallbackCount, 0);
      final clock = painterOf(tester).clock;
      await tester.pump(const Duration(seconds: 5));
      expect(clock.time, sceneStillTime);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('Calm visuals off holds the scene still', (tester) async {
      await tester.pumpWidget(scene());
      expect(tester.binding.transientCallbackCount, 1);
      await CalmVisualsSetting.instance.setEnabled(false);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      await CalmVisualsSetting.instance.setEnabled(true);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 1);
    });

    testWidgets('pauses while the app is in the background', (tester) async {
      await tester.pumpWidget(scene());
      expect(tester.binding.transientCallbackCount, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 1);
    });

    group('battery saver', () {
      late bool saver;
      late int asked;
      late StreamController<Object?> charging;
      final real = BatterySaver.instance;

      setUp(() {
        saver = false;
        asked = 0;
        charging = StreamController<Object?>.broadcast();
        BatterySaver.instance = BatterySaver.forTest(
          probe: () async {
            asked++;
            return saver;
          },
          changes: () => charging.stream,
        );
      });

      tearDown(() {
        BatterySaver.instance = real;
        charging.close();
      });

      testWidgets('on: the scene holds still', (tester) async {
        saver = true;
        await tester.pumpWidget(scene());
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 0);
        final clock = painterOf(tester).clock;
        await tester.pump(const Duration(seconds: 2));
        expect(clock.time, sceneStillTime);
      });

      testWidgets('switched off, it moves again on return to the app', (
        tester,
      ) async {
        saver = true;
        await tester.pumpWidget(scene());
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 0);
        saver = false;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 1);
      });

      testWidgets('re-checked on charge changes and once a minute', (
        tester,
      ) async {
        await tester.pumpWidget(scene());
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 1);
        final before = asked;
        saver = true;
        charging.add(null);
        await tester.pump();
        expect(asked, before + 1);
        expect(tester.binding.transientCallbackCount, 0);
        saver = false;
        await tester.pump(BatterySaver.recheckEvery);
        expect(asked, before + 2);
        expect(tester.binding.transientCallbackCount, 1);
      });

      testWidgets('stops checking when no scene is showing', (tester) async {
        await tester.pumpWidget(scene());
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        final before = asked;
        await tester.pump(BatterySaver.recheckEvery * 3);
        expect(asked, before);
      });
    });
  });
}
