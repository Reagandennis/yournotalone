import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/media/now_playing.dart';
import 'package:yournotalone/sounds/sound_player.dart';

import 'audio_fakes.dart';

/// Something showing on the lock screen, counting its button presses.
class _Session implements NowPlayingSession {
  _Session(this.lockScreen);

  final NowPlaying lockScreen;
  final pressed = <String>[];
  bool playing = true;

  @override
  Future<void> play() async {
    pressed.add('play');
    playing = true;
    lockScreen.update(this, playing: true);
  }

  @override
  Future<void> pause() async {
    pressed.add('pause');
    playing = false;
    lockScreen.update(this, playing: false);
  }

  @override
  Future<void> stop() async {
    pressed.add('stop');
    lockScreen.release(this);
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

  // As the catalogue names them (Deep focus is published online only).
  String assetOf(String id) => soundLibrary.firstWhere((s) => s.id == id).asset;
  late final deepFocus = assetOf('sound:Deep focus');
  late final brownNoise = assetOf('sound:Brown noise');

  late NowPlaying lockScreen;
  setUp(() async {
    lockScreen = freshNowPlaying();
    resetSoundPlayer();
    await SoundPlayer.instance.stop();
  });

  group('a sound on the lock screen', () {
    test('shows its name, its description and what it is', () async {
      await SoundPlayer.instance.play(deepFocus);

      expect(lockScreen.owner, same(SoundPlayer.instance));
      expect(shownItem!.title, 'Deep focus');
      expect(shownItem!.artist, 'Low, steady noise that softens distraction.');
      expect(shownItem!.album, 'Wellbeing sound · Focus');
      expect(shownItem!.displayDescription, shownItem!.artist);
      expect(shownState.playing, isTrue);
      expect(shownState.processingState, AudioProcessingState.ready);
      expect(shownState.controls, [MediaControl.pause, MediaControl.stop]);
      // Nothing to seek in a loop.
      expect(shownState.systemActions, isEmpty);
    });

    test('switching sounds changes the item, never clears it', () async {
      await SoundPlayer.instance.play(deepFocus);
      final states = <AudioProcessingState>[];
      final sub = lockScreen.playbackState.listen(
        (s) => states.add(s.processingState),
      );
      await SoundPlayer.instance.play(brownNoise);
      await pumpEventQueue();
      await sub.cancel();

      expect(shownItem!.title, 'Brown noise');
      expect(states, isNot(contains(AudioProcessingState.idle)));
    });

    test('pause, play and stop on the lock screen reach the app', () async {
      final player = SoundPlayer.instance;
      await player.play(deepFocus);

      await lockScreen.pause();
      expect(player.paused.value, isTrue);
      expect(shownState.playing, isFalse);
      expect(shownState.controls.first, MediaControl.play);

      await lockScreen.play();
      expect(player.paused.value, isFalse);
      expect(shownState.playing, isTrue);

      // The headset's single button toggles.
      await lockScreen.click();
      expect(player.paused.value, isTrue);

      await lockScreen.stop();
      expect(player.nowPlaying.value, isNull);
      expect(shownState.processingState, AudioProcessingState.idle);
      expect(lockScreen.owner, isNull);
    });

    test('swiping the notification away stops the sound', () async {
      await SoundPlayer.instance.play(deepFocus);
      await SoundPlayer.instance.pause();
      await lockScreen.onNotificationDeleted();
      expect(SoundPlayer.instance.nowPlaying.value, isNull);
      expect(shownState.processingState, AudioProcessingState.idle);
    });

    test('pausing in the app shows on the lock screen', () async {
      await SoundPlayer.instance.play(deepFocus);
      await SoundPlayer.instance.pause();
      expect(shownState.playing, isFalse);
      await SoundPlayer.instance.resume();
      expect(shownState.playing, isTrue);
    });
  });

  group('who owns the lock screen', () {
    test(
      'a meditation takes over; the sound under it can\'t clear it',
      () async {
        final player = SoundPlayer.instance;
        await player.play(deepFocus);

        final meditation = _Session(lockScreen);
        lockScreen.show(
          meditation,
          const MediaItem(id: 'meditation:Body scan', title: 'Body scan'),
          meditation,
        );
        lockScreen.update(meditation, playing: true);
        player.playUnderneath();

        await player.pause();
        await player.resume();
        await player.stop();
        expect(lockScreen.owner, same(meditation));
        expect(shownItem!.title, 'Body scan');
        expect(shownState.playing, isTrue);

        await lockScreen.pause();
        expect(meditation.pressed, ['pause']);

        lockScreen.release(meditation);
        expect(lockScreen.owner, isNull);
        expect(shownState.processingState, AudioProcessingState.idle);
      },
    );

    test('a sound started under a meditation never shows itself', () async {
      final meditation = _Session(lockScreen);
      lockScreen.show(
        meditation,
        const MediaItem(id: 'meditation:Body scan', title: 'Body scan'),
        meditation,
      );
      await SoundPlayer.instance.play(deepFocus, underneath: true);
      expect(shownItem!.title, 'Body scan');
      expect(lockScreen.owner, same(meditation));
    });
  });

  group('interruptions', () {
    late _Session session;
    setUp(() {
      session = _Session(lockScreen);
      lockScreen.show(session, const MediaItem(id: 'x', title: 'X'), session);
      lockScreen.update(session, playing: true);
    });

    test('a phone call pauses, and its end resumes', () {
      lockScreen.interrupted(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      expect(session.pressed, ['pause']);
      lockScreen.interrupted(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(session.pressed, ['pause', 'play']);
    });

    test('losing the audio for good only pauses', () {
      lockScreen.interrupted(
        AudioInterruptionEvent(true, AudioInterruptionType.unknown),
      );
      lockScreen.interrupted(
        AudioInterruptionEvent(false, AudioInterruptionType.unknown),
      );
      expect(session.pressed, ['pause']);
    });

    test('something paused by hand stays paused after a call', () async {
      await lockScreen.pause();
      lockScreen.interrupted(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      lockScreen.interrupted(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(session.pressed, ['pause']);
    });

    test('a navigation prompt only ducks', () {
      lockScreen.interrupted(
        AudioInterruptionEvent(true, AudioInterruptionType.duck),
      );
      lockScreen.interrupted(
        AudioInterruptionEvent(false, AudioInterruptionType.duck),
      );
      expect(session.pressed, isEmpty);
    });

    test('headphones coming out pause, for good', () {
      lockScreen.becameNoisy();
      lockScreen.interrupted(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      expect(session.pressed, ['pause']);
    });
  });
}
