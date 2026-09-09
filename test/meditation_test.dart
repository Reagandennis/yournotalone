import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/meditation/meditations_screen.dart';

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

    // Wind the whole session forward — completion state appears.
    await tester.pump(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Session complete'), findsOneWidget);
  });
}
