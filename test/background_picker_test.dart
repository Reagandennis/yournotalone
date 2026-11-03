import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/backgrounds/background_spec.dart';
import 'package:yournotalone/backgrounds/calm_visuals.dart';
import 'package:yournotalone/backgrounds/scene_background.dart';
import 'package:yournotalone/backgrounds/scene_library.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/content/catalog_snapshot.dart';
import 'package:yournotalone/meditation/breathing_screen.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/meditation/meditation_screen.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/sounds/player_screen.dart';
import 'package:yournotalone/sounds/sound_player.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
    );
  });

  tearDown(() {
    CalmVisualsSetting.instance.reset();
    SceneLibrary.instance.reset();
  });

  testWidgets('the player\'s background can be changed', (tester) async {
    SoundPlayer.instance.practice = PracticeRepository();
    addTearDown(SoundPlayer.instance.stop);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    SceneLibrary.instance.use(
      CatalogSnapshot.fromJson(
        jsonDecode(File(bundledCatalogAsset).readAsStringSync())
            as Map<String, dynamic>,
      )!,
    );
    final sound = soundsCatalog.firstWhere((s) => s.title == 'White noise');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: PlayerScreen(sound: sound),
      ),
    );
    await tester.pump();
    BackgroundSpec shown() =>
        tester.widget<SceneBackground>(find.byType(SceneBackground)).spec;
    expect(shown().id, 'dusk-waves');

    await tester.tap(find.byTooltip('Change background'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Fireflies'));
    await tester.pump();
    expect(
      CalmVisualsSetting.instance.choiceFor('sound:White noise'),
      'fireflies',
    );
    expect(
      tester
          .widgetList<SceneBackground>(find.byType(SceneBackground))
          .first
          .spec
          .id,
      'fireflies',
    );

    // Picking the sound's own background again clears the choice.
    await tester.tap(find.text('Dusk waves'));
    await tester.pump();
    expect(CalmVisualsSetting.instance.choiceFor('sound:White noise'), isNull);
  });

  for (final (name, itemId, screen) in [
    (
      'meditation',
      'meditation:${meditations.first.title}',
      () => MeditationScreen(
        meditation: meditations.first,
        practice: PracticeRepository(),
      ),
    ),
    (
      'breathing',
      'breathing:${breathPatterns.first.title}',
      () => BreathingScreen(
        pattern: breathPatterns.first,
        practice: PracticeRepository(),
      ),
    ),
  ]) {
    testWidgets('the $name screen\'s background can be changed', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      SceneLibrary.instance.use(
        CatalogSnapshot.fromJson(
          jsonDecode(File(bundledCatalogAsset).readAsStringSync())
              as Map<String, dynamic>,
        )!,
      );
      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: screen()),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Change background'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Fireflies'));
      await tester.pump();
      expect(CalmVisualsSetting.instance.choiceFor(itemId), 'fireflies');
      expect(
        tester
            .widgetList<SceneBackground>(find.byType(SceneBackground))
            .first
            .spec
            .id,
        'fireflies',
      );
    });
  }
}
