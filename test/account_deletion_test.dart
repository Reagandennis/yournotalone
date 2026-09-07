import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/settings_tab.dart';

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
      MaterialApp(theme: buildAppTheme(), home: Scaffold(body: screen));

  Future<void> openDeleteDialog(WidgetTester tester) async {
    await tester.pumpWidget(wrap(const SettingsTab()));
    await tester.pumpAndSettle();
    final row = find.text('Delete account');
    await tester.scrollUntilVisible(row, 100,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('deleting is a real flow, not a coming-soon toast',
      (tester) async {
    await openDeleteDialog(tester);

    // The old behaviour: `showComingSoon` with no onTap. Guard against it
    // coming back — the privacy policy, terms and FAQ all promise this works.
    expect(find.textContaining('coming soon'), findsNothing);
    expect(find.text('Delete your account?'), findsOneWidget);

    // It names what actually goes, so nobody deletes by surprise.
    expect(find.textContaining('journal entries'), findsOneWidget);
    expect(find.textContaining('can\'t be undone'), findsOneWidget);
  });

  testWidgets('it will not fire until you type DELETE', (tester) async {
    await openDeleteDialog(tester);

    TextButton confirmButton() => tester.widget<TextButton>(
          find.ancestor(
            of: find.text('Delete for good'),
            matching: find.byType(TextButton),
          ),
        );
    expect(confirmButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete me');
    await tester.pumpAndSettle();
    expect(confirmButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'delete');
    await tester.pumpAndSettle();
    expect(confirmButton().onPressed, isNotNull, reason: 'case-insensitive');

    // And there is always a way out.
    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsNothing);
  });
}
