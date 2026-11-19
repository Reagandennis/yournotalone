import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/media/media_links.dart';
import 'package:yournotalone/media/media_source.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/sounds/sound_player.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';
import 'package:yournotalone/sounds/sounds_screen.dart';

import 'audio_fakes.dart';

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
    freshNowPlaying();
    resetSoundPlayer();
    SoundPlayer.instance
      ..clock = DateTime.now
      ..practice = PracticeRepository();
    return SoundPlayer.instance.stop();
  });
  tearDown(resetSoundPlayer);

  test('pausing and stopping never wait on the practice write', () async {
    final practice = _StuckPractice();
    var now = DateTime(2026, 9, 18, 21);
    final player = SoundPlayer.instance
      ..practice = practice
      ..clock = () => now;

    final sound = soundLibrary.first;
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
    expect(find.text('Unlock with Premium'), findsOneWidget);
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
        soundLibrary.firstWhere((s) => s.title == 'Deep focus').asset);

    // Pause flips the control and the service state.
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(SoundPlayer.instance.paused.value, isTrue);
  });

  group('playback', () {
    const bundled = 'assets/sounds/brown_noise.m4a';
    const online = 'assets/sounds/rainfall.m4a';
    late FakeLoop loop;
    late Completer<File> download;

    setUp(() {
      loop = FakeLoop();
      download = Completer<File>();
      SoundPlayer.instance
        ..loopEngine = loop
        ..resolve = ((path) async => path == online
            ? RemoteAudio(remoteEntry(online))
            : BundledAudio(path))
        ..fetch = ((entry) => download.future);
    });

    test('a sound in the app plays at once', () async {
      await SoundPlayer.instance.play(bundled);
      expect(loop.log, ['stop', 'load $bundled', 'play']);
      expect(SoundPlayer.instance.isActive(bundled), isTrue);
    });

    test('paused while it downloads, it waits for play', () async {
      final player = SoundPlayer.instance;
      final playing = player.play(online);
      await pumpEventQueue();
      expect(player.preparing.value, online);
      expect(shownState.processingState, AudioProcessingState.loading);

      await player.pause();
      download.complete(downloadedFile('rain.m4a'));
      await playing;

      expect(loop.log, ['stop', 'load /tmp/rain.m4a']);
      expect(player.paused.value, isTrue);
      expect(player.preparing.value, isNull);
      expect(shownState.playing, isFalse);

      await player.resume();
      expect(loop.log.last, 'play');
      expect(shownState.playing, isTrue);
    });

    test('the newest choice wins over a slow download', () async {
      final player = SoundPlayer.instance;
      final first = player.play(online);
      await pumpEventQueue();
      await player.play(bundled);
      download.complete(downloadedFile('rain.m4a'));
      await first;

      expect(loop.loaded, bundled);
      expect(loop.log, isNot(contains('load /tmp/rain.m4a')));
      expect(player.nowPlaying.value, bundled);
      expect(shownItem!.title, 'Brown noise');
    });

    test('stopped while it downloads, nothing plays', () async {
      final player = SoundPlayer.instance;
      final playing = player.play(online);
      await pumpEventQueue();
      await player.stop();
      download.complete(downloadedFile('rain.m4a'));
      await playing;

      expect(loop.log, isNot(contains('play')));
      expect(loop.loaded, isNull);
      expect(player.nowPlaying.value, isNull);
      expect(player.preparing.value, isNull);
      expect(shownState.processingState, AudioProcessingState.idle);
    });

    test('a failed download clears the sound and says why', () async {
      final player = SoundPlayer.instance;
      final playing = player.play(online);
      await pumpEventQueue();
      download.completeError(const MediaUnavailable('offline'));
      await expectLater(playing, throwsA(isA<MediaUnavailable>()));
      expect(player.nowPlaying.value, isNull);
      expect(shownState.processingState, AudioProcessingState.idle);
    });

    test('a load cut short by the next sound is not an error', () async {
      final player = SoundPlayer.instance;
      final hold = loop.holdLoad = Completer<void>();
      final first = player.play(bundled);
      await pumpEventQueue(); // loading
      final second = player.play('assets/sounds/white_noise.m4a');
      await pumpEventQueue();
      // The first load fails because the second cut it short.
      loop.failLoad = Exception('Loading interrupted');
      hold.complete();
      await first; // doesn't throw
      await second;
      expect(player.nowPlaying.value, 'assets/sounds/white_noise.m4a');
      expect(loop.loaded, 'assets/sounds/white_noise.m4a');
    });

    test('playback that breaks shows as stopped, not as playing', () async {
      final player = SoundPlayer.instance;
      await player.play(bundled);
      loop.breakPlayback(Exception('damaged file'));
      await pumpEventQueue();
      expect(player.nowPlaying.value, isNull);
      expect(shownState.processingState, AudioProcessingState.idle);
    });

    testWidgets('the list shows a sound being fetched, and pause holds it', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 1400);
      addTearDown(tester.view.reset);
      // Deep focus, the free one, is published online only.
      final deepFocus = soundLibrary.firstWhere((s) => s.title == 'Deep focus');
      SoundPlayer.instance.resolve = (path) async =>
          RemoteAudio(remoteEntry(path, title: 'Deep focus'));

      await tester.pumpWidget(wrap(const SoundsScreen()));
      await tester.pumpAndSettle();
      final card = find.ancestor(
        of: find.text('Deep focus'),
        matching: find.byType(Material),
      );
      Finder inCard(Finder f) =>
          find.descendant(of: card.first, matching: f);

      await tester.tap(inCard(find.byIcon(Icons.play_arrow_rounded)));
      await tester.pump();
      expect(inCard(find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(inCard(find.byIcon(Icons.pause_rounded)), findsOneWidget);

      // Pause before it arrives: it mustn't start by itself.
      await tester.tap(inCard(find.byIcon(Icons.pause_rounded)));
      await tester.pump();
      expect(inCard(find.byIcon(Icons.play_arrow_rounded)), findsOneWidget);
      await tester.runAsync(() async {
        download.complete(downloadedFile('deep.m4a'));
        await pumpEventQueue();
      });
      await tester.pump();
      expect(loop.log, isNot(contains('play')));
      expect(SoundPlayer.instance.nowPlaying.value, deepFocus.asset);
      expect(inCard(find.byType(CircularProgressIndicator)), findsNothing);
      expect(inCard(find.byIcon(Icons.play_arrow_rounded)), findsOneWidget);

      await tester.tap(inCard(find.byIcon(Icons.play_arrow_rounded)));
      await tester.pump();
      expect(loop.log.last, 'play');
      expect(inCard(find.byIcon(Icons.pause_rounded)), findsOneWidget);
      await SoundPlayer.instance.stop();
    });
  });
}
