import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/cbt/activity_planner_screen.dart';
import 'package:yournotalone/cbt/cbt_catalog.dart';
import 'package:yournotalone/cbt/cbt_content.dart';
import 'package:yournotalone/cbt/cbt_screen.dart';
import 'package:yournotalone/cbt/grounding_screen.dart';
import 'package:yournotalone/cbt/problem_solving_screen.dart';
import 'package:yournotalone/cbt/thinking_traps_screen.dart';
import 'package:yournotalone/cbt/thought_record_screen.dart';
import 'package:yournotalone/cbt/worry_time_screen.dart';
import 'package:yournotalone/home/explore_tab.dart';
import 'package:yournotalone/journal/journal_repository.dart';

/// A journal that only remembers what was written to it.
class _FakeJournal extends JournalRepository {
  final saved = <(String?, String)>[];

  @override
  Future<int> countEntries() async => 0;

  @override
  Future<void> create({String? title, required String content}) async =>
      saved.add((title, content));
}

Widget _wrap(Widget screen) => MaterialApp(theme: buildAppTheme(), home: screen);

Finder _button(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

Future<Finder> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 150,
      scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  return finder;
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Explore\'s CBT card opens the toolkit', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(const Scaffold(body: ExploreTab())));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('CBT for Therapy'));
    await tester.tap(find.text('CBT for Therapy'));
    await tester.pumpAndSettle();

    expect(find.byType(CbtScreen), findsOneWidget);
    for (final tool in cbtTools) {
      expect(await _scrollTo(tester, find.text(tool.title)), findsOneWidget);
    }
    expect(await _scrollTo(tester, find.text('Free resources')), findsOneWidget);
    expect(
      await _scrollTo(tester, find.text(cbtResources.first.title)),
      findsOneWidget,
    );
  });

  testWidgets('every tool card opens its screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1600);
    addTearDown(tester.view.reset);
    const expected = {
      'Grounding: 5-4-3-2-1': GroundingScreen,
      'Thought record': ThoughtRecordScreen,
      'Thinking traps': ThinkingTrapsScreen,
      'One small thing': ActivityPlannerScreen,
      'Worry window': WorryTimeScreen,
      'Problem solving': ProblemSolvingScreen,
    };
    for (final entry in expected.entries) {
      await tester.pumpWidget(_wrap(const CbtScreen()));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text(entry.key));
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
      // Back to the hub, or the next round would tap through this route.
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('grounding counts 5-4-3-2-1 down to being here', (tester) async {
    await tester.pumpWidget(_wrap(const GroundingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('5 things you can see'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.tap(_button(i == 4 ? 'Found one — last' : 'Found one'));
      await tester.pumpAndSettle();
    }
    expect(find.text('4 things you can feel'), findsOneWidget);
    for (var i = 0; i < 4 + 3 + 2 + 1; i++) {
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();
    }
    expect(find.text('You\'re here'), findsOneWidget);
  });

  testWidgets('a thought record walks to a fairer thought and saves it',
      (tester) async {
    final journal = _FakeJournal();
    await tester.pumpWidget(_wrap(ThoughtRecordScreen(journal: journal)));
    await tester.pumpAndSettle();

    // Can't move on with nothing written.
    expect(tester.widget<ElevatedButton>(_button('Continue')).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'No reply all evening');
    await tester.pump();
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'She\'s had enough of me');
    await tester.pump();
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anxious'));
    await tester.pump();
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Any thinking traps in there?'), findsOneWidget);
    await tester.tap(find.text('Mind reading'));
    await tester.pump();
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();

    // The trap chosen brings its question along.
    expect(find.textContaining('What\'s my actual evidence?'), findsOneWidget);
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'She\'s busy at work this week');
    await tester.pump();
    await tester.tap(_button('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('How strong is the feeling now?'), findsOneWidget);
    await tester.tap(_button('Save to journal'));
    await tester.pumpAndSettle();

    expect(journal.saved, hasLength(1));
    expect(journal.saved.single.$1, 'Thought record');
    expect(journal.saved.single.$2, contains('Mind reading'));
    expect(journal.saved.single.$2, contains('She\'s busy at work this week'));
  });

  testWidgets('the planner keeps today\'s three and ticks them off',
      (tester) async {
    await tester.pumpWidget(_wrap(const ActivityPlannerScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ten-minute walk outside'));
    await tester.pumpAndSettle();
    expect(find.text('Today · 0 of 1 done'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(find.text('Today · 1 of 1 done'), findsOneWidget);

    // A fourth pick is turned down kindly.
    for (final label in ['Stretch for five minutes', 'Dance to one song']) {
      await _scrollTo(tester, find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await _scrollTo(tester, find.text('Take the stairs, or walk one stop'));
    await tester.tap(find.text('Take the stairs, or walk one stop'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Three is plenty'), findsOneWidget);

    // And it survives a restart.
    final plan = await ActivityPlan.load();
    expect(plan.picked, hasLength(3));
    expect(plan.done, {'Ten-minute walk outside'});
  });

  testWidgets('worries are parked, then decided inside the window',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const WorryTimeScreen(windowLength: Duration(seconds: 3)),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Rent is due on the 1st');
    await tester.tap(find.byIcon(Icons.local_parking_rounded));
    await tester.pumpAndSettle();
    expect(find.text('1 parked for worry time'), findsOneWidget);
    expect(find.text('Yes — plan it'), findsNothing);

    await tester.tap(_button('Open window'));
    await tester.pump();
    expect(find.text('00:03'), findsOneWidget);
    await tester.tap(find.text('Yes — plan it'));
    await tester.pump();
    expect(find.text('You\'ve got a plan for this one.'), findsOneWidget);

    // The window closes itself.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.textContaining('Time\'s up'), findsOneWidget);
    expect((await loadWorries()).single.outcome, 'plan');
  });

  testWidgets('a thinking trap opens to its example and question',
      (tester) async {
    await tester.pumpWidget(_wrap(const ThinkingTrapsScreen()));
    await tester.pumpAndSettle();

    expect(find.text(thinkingTraps.first.example), findsNothing);
    await tester.tap(find.text(thinkingTraps.first.name));
    await tester.pumpAndSettle();
    expect(find.text(thinkingTraps.first.example), findsOneWidget);
    expect(find.text(thinkingTraps.first.ask), findsOneWidget);
  });
}
