import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/mood_history_screen.dart';
import 'package:yournotalone/home/mood_repository.dart';
import 'package:yournotalone/home/mood_scale.dart';

/// Serves a fixed history so the screen can be checked without a backend.
class _FakeMoodRepo extends MoodRepository {
  _FakeMoodRepo(this.entries);

  final List<MoodEntry> entries;

  @override
  Future<List<MoodEntry>> fetchHistory({int days = 90}) async => entries;
}

class _FailingMoodRepo extends MoodRepository {
  @override
  Future<List<MoodEntry>> fetchHistory({int days = 90}) async =>
      throw Exception('offline');
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

  MoodEntry daysAgo(int back, int index) {
    final now = DateTime.now();
    return MoodEntry(
      date: DateTime(now.year, now.month, now.day - back),
      index: index,
    );
  }

  test('the mood scale lines up with what the database stores', () {
    expect(moodLevels.length, MoodRepository.moodKeys.length);
    for (final (i, level) in moodLevels.indexed) {
      expect(level.label.toLowerCase(), MoodRepository.moodKeys[i]);
    }
  });

  testWidgets('history summarises the run of check-ins', (tester) async {
    // Today plus the three days before it, then a gap, then one more.
    final repo = _FakeMoodRepo([
      daysAgo(0, 4), // Great
      daysAgo(1, 3), // Good
      daysAgo(2, 4), // Great
      daysAgo(3, 1), // Low
      daysAgo(9, 0), // Awful
    ]);
    await tester.pumpWidget(wrap(MoodHistoryScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget); // check-ins
    expect(find.text('4'), findsOneWidget); // day streak, ending today
    expect(find.text('3.4'), findsOneWidget); // average score
    expect(find.text('Great'), findsWidgets); // most days, and rows

    // Once under the strip as its right-hand caption, once as the row.
    expect(find.text('Today'), findsNWidgets(2));
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('a streak survives today not being logged yet', (tester) async {
    final repo = _FakeMoodRepo([daysAgo(1, 2), daysAgo(2, 2)]);
    await tester.pumpWidget(wrap(MoodHistoryScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsWidgets); // two check-ins, two-day streak
    // Only the strip caption — there is no row for today yet.
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('with no check-ins yet it says where to start',
      (tester) async {
    await tester.pumpWidget(
      wrap(MoodHistoryScreen(repository: _FakeMoodRepo(const []))),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No check-ins yet'), findsOneWidget);
  });

  testWidgets('offline it offers a retry', (tester) async {
    await tester.pumpWidget(
      wrap(MoodHistoryScreen(repository: _FailingMoodRepo())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t load your check-ins.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
