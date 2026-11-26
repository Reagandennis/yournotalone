import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/media/media_source.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/sounds/sound_player.dart';

import 'audio_fakes.dart';

/// A loop that remembers its volume.
class _VolumeLoop implements LoopEngine {
  double volume = 1;

  @override
  Future<void> load({String? asset, String? file}) async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setVolume(double v) async => volume = v;
  @override
  Stream<Object> get errors => const Stream.empty();
}

class _Practice extends PracticeRepository {
  final logged = <String>[];

  @override
  Future<void> logSession({
    required PracticeKind kind,
    required String slug,
    required String title,
    required double minutes,
  }) async => logged.add(title);
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

  late DateTime now;
  String? user;
  late _Practice practice;

  setUp(() {
    freshNowPlaying();
    resetSoundPlayer();
    now = DateTime(2026, 11, 26, 22);
    user = 'amina';
    practice = _Practice();
    SoundPlayer.instance
      ..clock = (() => now)
      ..userId = (() => user)
      ..practice = practice
      ..resolve = (path) async => BundledAudio(path);
  });
  tearDown(() async {
    await SoundPlayer.instance.stop();
    SoundPlayer.instance
      ..clock = DateTime.now
      ..userId = (() => null)
      ..practice = PracticeRepository();
    resetSoundPlayer();
  });

  final sound = soundLibrary.first;

  test('a listen is not credited to whoever signs in next', () async {
    final player = SoundPlayer.instance;
    await player.play(sound.asset);
    now = now.add(const Duration(minutes: 10));
    // Amina signs out, Bo signs in, and the sound is stopped.
    user = 'bo';
    await player.stop();
    expect(practice.logged, isEmpty);

    // Bo's own listen counts.
    await player.play(sound.asset);
    now = now.add(const Duration(minutes: 10));
    await player.stop();
    expect(practice.logged, [sound.title]);
  });

  testWidgets('cancelling the sleep timer during its fade restores the volume',
      (tester) async {
    final loop = _VolumeLoop();
    final player = SoundPlayer.instance..loopEngine = loop;
    await player.play(sound.asset);

    player.setSleepTimer(const Duration(seconds: 30));
    now = now.add(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 1));
    expect(loop.volume, lessThan(1));

    player.setSleepTimer(null);
    await tester.pump();
    expect(loop.volume, 1);

    // Changing it during the fade does the same.
    player.setSleepTimer(const Duration(seconds: 15));
    await tester.pump(const Duration(seconds: 1));
    expect(loop.volume, lessThan(1));
    player.setSleepTimer(const Duration(minutes: 30));
    await tester.pump();
    expect(loop.volume, 1);
    player.setSleepTimer(null);
    await player.stop();
  });
}
