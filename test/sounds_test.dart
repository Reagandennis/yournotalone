import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/sounds/sound_player.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';
import 'package:yournotalone/sounds/sounds_screen.dart';

/// A repository whose writes never come back — a dead connection.
class _StuckPractice extends PracticeRepository {
  final logged = <(String, double)>[];

  @override
  Future<void> logSession({
    required PracticeKind kind,
    required String slug,
    required String title,
    required double minutes,
  }) async {
    logged.add((title, minutes));
    await Completer<void>().future;
  }
}

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

  setUp(() {
    SoundPlayer.instance
      ..clock = DateTime.now
      ..practice = PracticeRepository();
    return SoundPlayer.instance.stop();
  });

  test('pausing and stopping never wait on the practice write', () async {
    final practice = _StuckPractice();
    var now = DateTime(2026, 9, 18, 21);
    final player = SoundPlayer.instance
      ..practice = practice
      ..clock = () => now;

    final sound = soundsCatalog.first;
    await player.play(sound.asset);
    now = now.add(const Duration(minutes: 5));

    // The write hangs forever; pause must not.
    await player.pause().timeout(const Duration(seconds: 1));
    expect(player.paused.value, isTrue);
    expect(practice.logged, [(sound.title, 5.0)]);

    // Resume, listen on, and stop: same again.
    await player.resume();
    now = now.add(const Duration(minutes: 4));
    await player.stop().timeout(const Duration(seconds: 1));
    expect(player.nowPlaying.value, isNull);
    expect(practice.logged, hasLength(2));
    expect(practice.logged.last.$2, 4.0);
  });

  Widget wrap(Widget screen) =>
      MaterialApp(theme: buildAppTheme(), home: screen);

  test('every catalogued sound ships as a real asset', () {
    for (final sound in [...soundsCatalog.map((s) => s.asset), chimeAsset]) {
      final file = File(sound);
      expect(file.existsSync(), isTrue, reason: 'missing asset: $sound');
      expect(file.lengthSync(), greaterThan(10 * 1024), reason: 'stub: $sound');
    }
  });

  test('one sound is free to try, the rest are Premium', () {
    final free = soundsCatalog.where((s) => !s.premium).toList();
    expect(free.map((s) => s.title), ['Deep focus']);
    expect(soundsCatalog.length, 13);
  });

  testWidgets('sounds screen lists the library with category filters',
      (tester) async {
    await tester.pumpWidget(wrap(const SoundsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Wellbeing sounds'), findsOneWidget);
    expect(find.text('Deep focus'), findsOneWidget);

    // Locked sounds carry the Premium chip; the free one doesn't.
    Finder chipIn(String title) => find.descendant(
          of: find
              .ancestor(of: find.text(title), matching: find.byType(Material))
              .first,
          matching: find.text('Premium'),
        );
    expect(chipIn('Deep focus'), findsNothing);
    expect(chipIn('White noise'), findsOneWidget);

    // Filter down to Sleep.
    await tester.tap(find.text('Sleep'));
    await tester.pumpAndSettle();
    expect(find.text('Rainfall'), findsOneWidget);
    expect(find.text('Crickets at night'), findsOneWidget);
    expect(find.text('Deep focus'), findsNothing);

    // Back to all.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Deep focus'), findsOneWidget);
  });

  testWidgets('locked sound opens the upgrade sheet for free users',
      (tester) async {
    await tester.pumpWidget(wrap(const SoundsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('White noise'));
    await tester.pumpAndSettle();
    expect(find.text('This sound is part of Premium'), findsOneWidget);
    expect(find.text('See Premium'), findsOneWidget);
  });

  testWidgets('free sound opens the player, autoplays, and can pause',
      (tester) async {
    // A real phone, not the 800x600 default: the player fills the screen.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(const SoundsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deep focus'));
    await tester.pump(); // start route transition
    await tester.pump(const Duration(seconds: 1)); // finish transition
    await tester.pump(); // reflect post-frame autoplay state

    // Player screen with the sound playing (pause shown) and controls.
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(SoundPlayer.instance.nowPlaying.value,
        'assets/sounds/deep_focus.m4a');

    // Pause flips the control and the service state.
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(SoundPlayer.instance.paused.value, isTrue);
  });
}
