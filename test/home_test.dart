import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/app_navigation.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/home_shell.dart';
import 'package:yournotalone/home/home_tab.dart';
import 'package:yournotalone/home/mood_face.dart';
import 'package:yournotalone/home/mood_repository.dart';
import 'package:yournotalone/home/settings_tab.dart';
import 'package:yournotalone/practice/practice_repository.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';

class _NoPractice extends PracticeRepository {
  @override
  Future<List<PracticeSession>> fetchRecent({int days = 120}) async =>
      const [];
}

/// Today's saved check-in, as the server would answer.
class _Moods extends MoodRepository {
  int? today;
  bool offline = false;

  @override
  Future<int?> fetchTodayMoodIndex() async {
    if (offline) throw Exception('offline');
    return today;
  }

  @override
  Future<List<MoodEntry>> fetchHistory({int days = 90}) async => const [];

  /// Saves fail while this is set.
  bool saveFails = false;
  final saved = <int>[];

  @override
  Future<void> saveMood(int index) async {
    if (saveFails) throw Exception('offline');
    saved.add(index);
    today = index;
  }
}

/// The app sent to the background and brought back.
void _awayAndBack(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  // Supabase starts its sign-in refresh timer on the way back; nothing
  // here is signed in, and the test can't end with it running.
  Supabase.instance.client.auth.stopAutoRefresh();
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

  testWidgets('home shell switches between the three tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const HomeShell()),
    );
    await tester.pumpAndSettle();

    // Home tab is up first: mood check-in, then quick access further down.
    expect(find.text('How are you feeling today?'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Quick access'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(HomeTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Quick access'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('What do you need right now?'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Free plan'), findsOneWidget);

    final logoutFinder = find.text('Log out');
    await tester.scrollUntilVisible(
      logoutFinder,
      80,
      scrollable: find
          .descendant(
            of: find.byType(SettingsTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(logoutFinder, findsOneWidget);
  });

  testWidgets('mood check-in lights up the selected face', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: HomeTab(practice: _NoPractice(), mood: _Moods()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Only the faces in the check-in row: an Awful pick opens a sheet with
    // its own, and the week strip below repeats today's pick.
    MoodFace face(String label) => tester.widget<MoodFace>(
          find
              .descendant(
                of: find.byType(HomeTab),
                matching: find.byWidgetPredicate(
                  (w) => w is MoodFace && w.level.label == label,
                ),
              )
              .first,
        );
    // Nothing picked yet: every face is in full colour.
    expect(face('Great').dimmed, isFalse);
    expect(face('Awful').dimmed, isFalse);

    await tester.tap(find.text('Great'));
    await tester.pumpAndSettle();
    expect(face('Great').dimmed, isFalse);
    expect(face('Awful').dimmed, isTrue);

    // Picking a different mood moves the emphasis.
    await tester.tap(find.text('Awful'));
    await tester.pumpAndSettle();
    expect(face('Awful').dimmed, isFalse);
    expect(face('Great').dimmed, isTrue);
  });

  testWidgets('a check-in that fails to save does not stay lit as saved', (
    tester,
  ) async {
    final moods = _Moods()..saveFails = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: HomeTab(practice: _NoPractice(), mood: moods)),
      ),
    );
    await tester.pumpAndSettle();
    MoodFace face(String label) => tester.widget<MoodFace>(
          find
              .descendant(
                of: find.byType(HomeTab),
                matching: find.byWidgetPredicate(
                  (w) => w is MoodFace && w.level.label == label,
                ),
              )
              .first,
        );

    await tester.tap(find.text('Great'));
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t save your mood — check your connection.'),
        findsOneWidget);
    // Back to nothing picked: every face in full colour.
    expect(face('Great').dimmed, isFalse);
    expect(face('Awful').dimmed, isFalse);

    moods.saveFails = false;
    await tester.tap(find.text('Great'));
    await tester.pumpAndSettle();
    expect(moods.saved, [4]);
    expect(face('Awful').dimmed, isTrue);
  });

  group('Home catches up', () {
    late int fetches;
    late _Moods moods;
    late ValueNotifier<int> shown;

    setUp(() {
      fetches = 0;
      moods = _Moods();
      shown = ValueNotifier(0);
    });

    Widget home() => MaterialApp(
          theme: buildAppTheme(),
          navigatorObservers: [appRouteObserver],
          home: Scaffold(
            body: HomeTab(
              practice: _NoPractice(),
              mood: moods,
              therapyRequests: () async {
                fetches++;
                return const <TherapyRequest>[];
              },
              reselected: shown,
            ),
          ),
        );

    MoodFace face(WidgetTester tester, String label) =>
        tester.widget<MoodFace>(
          find
              .descendant(
                of: find.byType(HomeTab),
                matching: find.byWidgetPredicate(
                  (w) => w is MoodFace && w.level.label == label,
                ),
              )
              .first,
        );

    testWidgets('when a page opened on it is closed', (tester) async {
      await tester.pumpWidget(home());
      await tester.pumpAndSettle();
      expect(fetches, 1);

      final navigator = Navigator.of(tester.element(find.byType(HomeTab)));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('A practice')),
        ),
      );
      await tester.pumpAndSettle();
      expect(fetches, 1);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(fetches, 2);

      // Every time, however soon.
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('A course')),
        ),
      );
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(fetches, 3);

      // A sheet isn't a page.
      showModalBottomSheet<void>(
        context: tester.element(find.byType(HomeTab)),
        builder: (_) => const Text('A sheet'),
      );
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(fetches, 3);
    });

    testWidgets('back in the app or on the tab, unless that was moments ago',
        (tester) async {
      final pumped = clock;
      var later = Duration.zero;
      await withClock(Clock(() => pumped.now().add(later)), () async {
        await tester.pumpWidget(home());
        await tester.pumpAndSettle();
        expect(fetches, 1);

        later += const Duration(seconds: 10);
        _awayAndBack(tester);
        await tester.pumpAndSettle();
        expect(fetches, 1);

        later += const Duration(minutes: 5);
        _awayAndBack(tester);
        await tester.pumpAndSettle();
        expect(fetches, 2);

        shown.value++;
        await tester.pumpAndSettle();
        expect(fetches, 2);

        later += const Duration(minutes: 1);
        shown.value++;
        await tester.pumpAndSettle();
        expect(fetches, 3);
      });
    });

    testWidgets('and yesterday\'s check-in isn\'t lit today', (tester) async {
      var now = DateTime(2026, 11, 19, 21);
      moods.today = 3;
      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(home());
        await tester.pumpAndSettle();
        expect(face(tester, 'Good').dimmed, isFalse);
        expect(face(tester, 'Great').dimmed, isTrue);

        // The next morning, and the server can't be reached: the check-in
        // goes dark anyway.
        now = DateTime(2026, 11, 20, 7);
        moods.offline = true;
        _awayAndBack(tester);
        await tester.pumpAndSettle();
        expect(face(tester, 'Good').dimmed, isFalse);
        expect(face(tester, 'Great').dimmed, isFalse);

        // Today's own, once it's there.
        moods
          ..offline = false
          ..today = 1;
        now = now.add(const Duration(minutes: 1));
        _awayAndBack(tester);
        await tester.pumpAndSettle();
        expect(face(tester, 'Low').dimmed, isFalse);
        expect(face(tester, 'Good').dimmed, isTrue);
      });
    });
  });
}
