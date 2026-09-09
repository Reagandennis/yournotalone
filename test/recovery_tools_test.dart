import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/journal/journal_repository.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/recovery/halt_screen.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';
import 'package:yournotalone/recovery/insights_screen.dart';
import 'package:yournotalone/recovery/milestones_screen.dart';
import 'package:yournotalone/recovery/recovery_repository.dart';
import 'package:yournotalone/recovery/tape_forward_screen.dart';

class _FakeRecoveryRepo extends RecoveryRepository {
  _FakeRecoveryRepo({this.habits = const [], this.cravings = const []});

  final List<RecoveryHabit> habits;
  final List<CravingLog> cravings;

  @override
  Future<List<RecoveryHabit>> fetchHabits() async => habits;

  @override
  Future<List<CravingLog>> fetchCravings({int days = 90}) async => cravings;
}

/// Records what the tape-forward tool writes, instead of hitting Supabase.
class _RecordingJournal extends JournalRepository {
  String? title;
  String? content;

  @override
  Future<void> create({String? title, required String content}) async {
    this.title = title;
    this.content = content;
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

  Widget wrap(Widget screen) =>
      MaterialApp(theme: buildAppTheme(), home: screen);

  /// Gives the test a phone-width but very tall screen, so a whole form
  /// is laid out at once and no finder is chasing an unmounted widget.
  void tallScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 2400);
    addTearDown(tester.view.reset);
  }

  CravingLog craving(String trigger, int intensity, DateTime at) => CravingLog(
        id: at.toString(),
        intensity: intensity,
        trigger: trigger,
        note: null,
        createdAt: at,
      );

  // ── HALT ────────────────────────────────────────────────────────

  test('HALT still points at real catalogue entries', () {
    // The screen looks these up by title. A rename used to throw on open;
    // now it falls back silently, so this is what catches the break.
    for (final title in haltMeditationTitles) {
      expect(meditations.map((m) => m.title), contains(title));
    }
    for (final title in haltSoundTitles) {
      expect(soundsCatalog.map((s) => s.title), contains(title));
    }
  });

  testWidgets('HALT answers back only for what you tick', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(wrap(const HaltScreen()));
    await tester.pumpAndSettle();

    // Nothing ticked: it says the urge is on its own.
    expect(find.textContaining('None of them?'), findsOneWidget);

    const angryOption = 'Is something still sitting unsaid?';
    await tester.tap(find.text(angryOption));
    await tester.pumpAndSettle();
    expect(find.textContaining('None of them?'), findsNothing);
    expect(find.text('What that means'), findsOneWidget);
    expect(find.text('Letting go of anger · 9 min'), findsOneWidget);

    // A second need adds its own answer; both stay.
    await tester.tap(find.text('Have you slept properly this week?'));
    await tester.pumpAndSettle();
    expect(find.text('Wind down and sleep'), findsOneWidget);
    expect(find.text('Letting go of anger · 9 min'), findsOneWidget);

    // Un-ticking removes just that one.
    await tester.tap(find.text(angryOption));
    await tester.pumpAndSettle();
    expect(find.text('Letting go of anger · 9 min'), findsNothing);
    expect(find.text('Wind down and sleep'), findsOneWidget);
  });

  testWidgets('HALT sends you to the tool that matches', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(wrap(const HaltScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Is something still sitting unsaid?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Letting go of anger · 9 min'));
    // The meditation backdrop never stops animating, so settle by hand.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Letting go of anger'), findsWidgets);
  });

  // ── Play the tape forward ───────────────────────────────────────

  testWidgets('tape forward saves only what you wrote', (tester) async {
    tallScreen(tester);
    final journal = _RecordingJournal();
    await tester.pumpWidget(wrap(TapeForwardScreen(journal: journal)));
    await tester.pumpAndSettle();

    ElevatedButton saveButton() => tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Keep this in my journal'),
            matching: find.byType(ElevatedButton),
          ),
        );
    expect(saveButton().onPressed, isNull); // nothing written yet

    // Answer the first step only, addressed by its own hint.
    await tester.enterText(
      find.ancestor(
        of: find.text('Not the first five minutes — the hour.'),
        matching: find.byType(TextField),
      ),
      'Back to day one.',
    );
    await tester.pumpAndSettle();
    expect(saveButton().onPressed, isNotNull);

    await tester.tap(find.text('Keep this in my journal'));
    await tester.pumpAndSettle();

    expect(journal.title, 'Playing the tape forward');
    expect(journal.content, contains('In an hour'));
    expect(journal.content, contains('Back to day one.'));
    // The steps left blank stay out of the entry.
    expect(journal.content, isNot(contains('A week from now')));
  });

  // ── Milestones ──────────────────────────────────────────────────

  testWidgets('milestones mark what is done and what is next',
      (tester) async {
    final repo = _FakeRecoveryRepo(habits: [
      RecoveryHabit(
        id: 'h1',
        name: 'Alcohol',
        dayOne: DateTime.now().subtract(const Duration(days: 9)),
        bestStreakDays: 0,
        pledgedToday: false,
      ),
    ]);
    await tester.pumpWidget(wrap(MilestonesScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('Alcohol'), findsOneWidget);
    expect(find.text('Day 10'), findsOneWidget);
    // Day one, 3 days and 1 week are behind; 2 weeks is next.
    expect(find.text('3 of 9 reached'), findsOneWidget);
    expect(find.text('4 days to go'), findsOneWidget);
  });

  testWidgets('milestones point you at adding a commitment first',
      (tester) async {
    await tester.pumpWidget(wrap(MilestonesScreen(repository: _FakeRecoveryRepo())));
    await tester.pumpAndSettle();
    expect(find.textContaining('No commitments yet'), findsOneWidget);
  });

  // ── Trigger insights ────────────────────────────────────────────

  testWidgets('insights rank the triggers and name the pattern',
      (tester) async {
    final today = DateTime.now();
    DateTime at(int daysAgo, int hour) =>
        DateTime(today.year, today.month, today.day - daysAgo, hour);
    final repo = _FakeRecoveryRepo(cravings: [
      craving('Stress', 4, at(1, 21)),
      craving('Stress', 5, at(2, 20)),
      craving('Stress', 3, at(3, 22)),
      craving('Boredom', 2, at(4, 14)),
      craving('Loneliness', 3, at(5, 23)),
    ]);
    await tester.pumpWidget(wrap(TriggerInsightsScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('5'), findsWidgets); // logged, and strongest
    expect(find.text('3.4'), findsOneWidget); // average intensity
    expect(find.text('Evening'), findsWidgets); // usual time, and its bar
    expect(
      find.textContaining('Stress in the evening is your pattern'),
      findsOneWidget,
    );
    expect(find.text('Stress'), findsOneWidget);
    expect(find.text('Boredom'), findsOneWidget);
  });

  testWidgets('insights explain themselves before there is data',
      (tester) async {
    await tester.pumpWidget(
      wrap(TriggerInsightsScreen(repository: _FakeRecoveryRepo())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing logged'), findsOneWidget);
  });
}
