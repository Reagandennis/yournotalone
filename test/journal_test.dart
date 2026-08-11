import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/journal/journal_editor_screen.dart';
import 'package:yournotalone/journal/journal_screen.dart';

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

  testWidgets('journal list shows a friendly error when offline',
      (tester) async {
    await tester.pumpWidget(wrap(const JournalScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Couldn\'t load your journal.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('editor enables save only once there is content',
      (tester) async {
    await tester.pumpWidget(wrap(const JournalEditorScreen()));
    await tester.pumpAndSettle();

    ElevatedButton saveButton() => tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Save entry'),
            matching: find.byType(ElevatedButton),
          ),
        );
    expect(saveButton().onPressed, isNull);

    await tester.enterText(
      find.byType(TextField).last,
      'Today was heavy, but I made it.',
    );
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);
  });

  testWidgets('gratitude prompt pre-fills the editor', (tester) async {
    await tester.pumpWidget(wrap(const JournalEditorScreen(
      initialTitle: 'Gratitude',
      initialContent: 'Today, I\'m grateful for ',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Gratitude'), findsOneWidget);
    expect(find.text('Today, I\'m grateful for '), findsOneWidget);
  });
}
