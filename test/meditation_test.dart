import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/content/content_catalog.dart';
import 'package:yournotalone/media/download_strings.dart';
import 'package:yournotalone/media/media_links.dart';
import 'package:yournotalone/media/media_source.dart';
import 'package:yournotalone/media/now_playing.dart';
import 'package:yournotalone/meditation/breathing_screen.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/meditation/meditation_screen.dart';
import 'package:yournotalone/meditation/meditations_screen.dart';
import 'package:yournotalone/sounds/sound_player.dart';

import 'audio_fakes.dart';

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

  Widget wrap(Widget screen) =>
      MaterialApp(theme: buildAppTheme(), home: screen);

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      80,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('hub lists breathing exercises and meditations',
      (tester) async {
    await tester.pumpWidget(wrap(const MeditationsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Meditations & breathing'), findsOneWidget);
    expect(find.text('Box breathing'), findsOneWidget);
    expect(find.text('4-7-8 calm'), findsOneWidget);
    await scrollTo(tester, 'Morning grounding');
    expect(find.text('Morning grounding'), findsOneWidget);
  });

  testWidgets('locked session opens the upgrade sheet', (tester) async {
    await tester.pumpWidget(wrap(const MeditationsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('4-7-8 calm'));
    await tester.pumpAndSettle();
    expect(find.text('This session is part of Premium'), findsOneWidget);
  });

  testWidgets('box breathing runs a session with phase guidance',
      (tester) async {
    await tester.pumpWidget(wrap(const MeditationsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Box breathing'));
    // Not pumpAndSettle: the session backdrop animates continuously, so
    // there is no settled state to wait for. Pump the route transition.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Setup view: rhythm, duration chips, begin.
    expect(find.text('4 · 4 · 4 · 4'), findsOneWidget);
    expect(find.text('1 min'), findsOneWidget);
    await tester.tap(find.text('1 min'));
    await tester.pump();

    await tester.tap(find.text('Begin'));
    await tester.pump();
    expect(find.text('Breathe in'), findsOneWidget);

    // 5 s in (4 s inhale done) we should be holding.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Hold'), findsOneWidget);

    // After the full minute the completion view appears.
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(find.text('Well done'), findsOneWidget);
  });

  testWidgets('a breathing exercise can be run again, after ending it and '
      'after finishing it', (tester) async {
    await tester.pumpWidget(wrap(BreathingScreen(pattern: breathPatterns.first)));
    await tester.pump();
    await tester.tap(find.text('1 min'));
    await tester.pump();

    // Run, end early, run again.
    await tester.tap(find.text('Begin'));
    await tester.pump();
    expect(find.text('Breathe in'), findsOneWidget);
    await tester.tap(find.byTooltip('End session'));
    await tester.pump();
    expect(find.text('Begin'), findsOneWidget);
    await tester.tap(find.text('Begin'));
    await tester.pump();
    expect(find.text('Breathe in'), findsOneWidget);
    // The second run starts from the top, not where the first stopped.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Hold'), findsOneWidget);

    // Finish, then go again.
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(find.text('Well done'), findsOneWidget);
    await tester.tap(find.text('Go again'));
    await tester.pump();
    expect(find.text('Breathe in'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Hold'), findsOneWidget);

    // And it still completes a second time.
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(find.text('Well done'), findsOneWidget);
  });

  testWidgets('free meditation opens and shows guidance', (tester) async {
    await tester.pumpWidget(wrap(const MeditationsScreen()));
    await tester.pumpAndSettle();

    await scrollTo(tester, 'Morning grounding');
    await tester.tap(find.text('Morning grounding'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('remaining'), findsOneWidget);
    expect(
      find.text('Find a comfortable seat and let your eyes soften or close.'),
      findsOneWidget,
    );

    // The guidance moves on with the clock, without anyone touching the
    // screen: 18% of five minutes is 54 s, 32% is 96 s. The extra second
    // lets the previous line finish sliding away.
    await tester.pump(const Duration(seconds: 60));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Feel the weight of your body — held and supported.'),
        findsOneWidget);
    expect(
      find.text('Find a comfortable seat and let your eyes soften or close.'),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 60));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Notice your breath moving on its own. No need to change it.'),
      findsOneWidget,
    );

    // Wind the whole session forward — completion state appears.
    await tester.pump(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Session complete'), findsOneWidget);
  });

  group('a meditation playing', () {
    final grounding = meditations.firstWhere(
      (m) => m.title == 'Morning grounding',
    );
    const voiced = Meditation(
      'Body scan',
      'Travel slowly through the body.',
      5,
      Icons.accessibility_new_rounded,
      Pillars.blue,
      premium: false,
      prompts: [(0.0, 'Settle in.'), (0.5, 'Notice your feet.')],
      narration: 'assets/narration/body_scan.m4a',
    );
    late FakeLoop loop;
    late FakeVoice voice;
    late String deepFocus;

    setUp(() async {
      freshNowPlaying();
      resetSoundPlayer();
      await SoundPlayer.instance.stop();
      loop = FakeLoop();
      voice = FakeVoice();
      SoundPlayer.instance
        ..loopEngine = loop
        ..voiceEngine = voice
        ..resolve = ((path) async => BundledAudio(path));
      deepFocus = soundLibrary.firstWhere((s) => s.title == 'Deep focus').asset;
    });
    tearDown(() async {
      await SoundPlayer.instance.stop();
      resetSoundPlayer();
    });

    Future<void> open(WidgetTester tester, Meditation meditation) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(MeditationScreen(meditation: meditation)));
      await tester.pump(); // starts after the first frame
    }

    Future<void> leave(WidgetTester tester) async {
      await tester.pumpWidget(wrap(const SizedBox()));
      await tester.pump();
    }

    String clockText(WidgetTester tester) => tester
        .widget<Text>(
          find.descendant(
            of: find.byType(ListenableBuilder),
            matching: find.byWidgetPredicate(
              (w) => w is Text && RegExp(r'^\d+:\d\d$').hasMatch(w.data ?? ''),
            ),
          ),
        )
        .data!;

    bool chipSelected(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style!.color ==
        BrandColors.light.onInk;

    testWidgets('shows on the lock screen with its picture\'s details', (
      tester,
    ) async {
      await open(tester, grounding);
      final lockScreen = NowPlaying.instance;
      expect(lockScreen.owner, isA<State<MeditationScreen>>());
      expect(shownItem!.title, 'Morning grounding');
      expect(shownItem!.artist, grounding.detail);
      expect(shownItem!.album, 'Guided meditation · 5 min');
      expect(shownItem!.duration, const Duration(minutes: 5));
      expect(shownState.playing, isTrue);

      await tester.pump(const Duration(seconds: 30));
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      // Where it stopped, for the lock screen's progress bar.
      expect(shownState.playing, isFalse);
      expect(shownState.updatePosition, const Duration(seconds: 30));

      await leave(tester);
      expect(lockScreen.owner, isNull);
      expect(shownState.processingState, AudioProcessingState.idle);
    });

    testWidgets('the play button pauses the clock and the sound under it', (
      tester,
    ) async {
      await open(tester, grounding);
      await tester.tap(find.text('Deep focus'));
      await tester.pump();
      expect(loop.log, containsAllInOrder(['load $deepFocus', 'play']));
      expect(chipSelected(tester, 'Deep focus'), isTrue);
      // The sound under it leaves the lock screen to the meditation.
      expect(shownItem!.title, 'Morning grounding');

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(SoundPlayer.instance.paused.value, isTrue);
      expect(loop.log.last, 'pause');
      final stopped = clockText(tester);
      await tester.pump(const Duration(seconds: 20));
      expect(clockText(tester), stopped);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(SoundPlayer.instance.isActive(deepFocus), isTrue);
      expect(loop.log.last, 'play');
      await tester.pump(const Duration(seconds: 20));
      expect(clockText(tester), isNot(stopped));

      // Leaving stops the sound it started.
      await leave(tester);
      expect(SoundPlayer.instance.nowPlaying.value, isNull);
    });

    testWidgets('the lock screen\'s buttons move the one on screen', (
      tester,
    ) async {
      await open(tester, grounding);
      final lockScreen = NowPlaying.instance;

      await lockScreen.pause();
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      final stopped = clockText(tester);
      await tester.pump(const Duration(seconds: 10));
      expect(clockText(tester), stopped);

      await lockScreen.play();
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Stop clears the lock screen and pauses; play here brings it back.
      await lockScreen.stop();
      await tester.pump();
      expect(lockScreen.owner, isNull);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(lockScreen.owner, isA<State<MeditationScreen>>());
      expect(shownState.playing, isTrue);
      await leave(tester);
    });

    testWidgets('a call pauses the session, and hanging up resumes it', (
      tester,
    ) async {
      await open(tester, grounding);
      NowPlaying.instance.interrupted(
        AudioInterruptionEvent(true, AudioInterruptionType.pause),
      );
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      NowPlaying.instance.interrupted(
        AudioInterruptionEvent(false, AudioInterruptionType.pause),
      );
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      await leave(tester);
    });

    testWidgets('a sound already playing carries on under it', (tester) async {
      await SoundPlayer.instance.play(deepFocus);
      await open(tester, grounding);

      expect(chipSelected(tester, 'Deep focus'), isTrue);
      expect(chipSelected(tester, 'No sound'), isFalse);
      expect(SoundPlayer.instance.isActive(deepFocus), isTrue);
      expect(shownItem!.title, 'Morning grounding');

      await leave(tester);
      expect(SoundPlayer.instance.nowPlaying.value, isNull);
    });

    testWidgets('a paused sound doesn\'t come back under it', (tester) async {
      await SoundPlayer.instance.play(deepFocus);
      await SoundPlayer.instance.pause();
      await open(tester, grounding);
      expect(SoundPlayer.instance.nowPlaying.value, isNull);
      expect(chipSelected(tester, 'No sound'), isTrue);
      await leave(tester);
    });

    testWidgets('a sound picked while paused waits for the session', (
      tester,
    ) async {
      await open(tester, grounding);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      loop.log.clear();

      await tester.tap(find.text('Deep focus'));
      await tester.pump();
      expect(loop.log, contains('load $deepFocus'));
      expect(loop.log, isNot(contains('play')));

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(loop.log.last, 'play');
      await leave(tester);
    });

    testWidgets('a sound that can\'t come says why, and lets go of the chip', (
      tester,
    ) async {
      SoundPlayer.instance.resolve = (path) async =>
          throw const MediaUnavailable('offline');
      await open(tester, grounding);
      await tester.tap(find.text('Deep focus'));
      await tester.pump();
      await tester.pump();
      expect(find.text(DownloadStrings.needsConnection), findsOneWidget);
      expect(chipSelected(tester, 'Deep focus'), isFalse);
      expect(chipSelected(tester, 'No sound'), isTrue);
      await leave(tester);
    });

    testWidgets('leaving while a sound is fetched means it never plays', (
      tester,
    ) async {
      final download = Completer<void>();
      SoundPlayer.instance
        ..resolve = ((path) async => RemoteAudio(remoteEntry(path)))
        ..fetch = ((entry) async {
          await download.future;
          return downloadedFile('deep.m4a');
        });
      await open(tester, grounding);
      await tester.tap(find.text('Deep focus'));
      await tester.pump();
      // The chip answers at once, with a spinner while it's fetched.
      expect(chipSelected(tester, 'Deep focus'), isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await leave(tester);
      download.complete();
      await tester.pump();
      expect(loop.log, isNot(contains('play')));
      expect(SoundPlayer.instance.nowPlaying.value, isNull);
    });

    testWidgets('one line of guidance fades into the next', (tester) async {
      await open(tester, grounding);
      // The second line is due at 7% of five minutes: 21 s.
      await tester.pump(const Duration(seconds: 21));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Find a comfortable seat and let your eyes soften or close.'),
        findsOneWidget,
      );
      expect(
        find.text('Take a slow breath in… and let it all the way out.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Find a comfortable seat and let your eyes soften or close.'),
        findsNothing,
      );
      await leave(tester);
    });

    testWidgets('the voice stays in step with the clock', (tester) async {
      await open(tester, voiced);
      await tester.pump();
      expect(voice.log, ['start narration/body_scan.m4a at 0s']);

      await tester.pump(const Duration(seconds: 30));
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(voice.log.last, 'pause');

      await tester.pump(const Duration(seconds: 10));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      expect(voice.log.sublist(voice.log.length - 2), ['seek 30s', 'resume']);

      // Off for twenty seconds; back on where the session is, not where
      // the voice stopped.
      await tester.tap(find.text('Voice'));
      await tester.pump();
      expect(voice.log.last, 'pause');
      await tester.pump(const Duration(seconds: 20));
      await tester.tap(find.text('Voice'));
      await tester.pump();
      expect(voice.log.sublist(voice.log.length - 2), ['seek 50s', 'resume']);

      await leave(tester);
      expect(voice.log.last, 'stop');
    });
  });
}
