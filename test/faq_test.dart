import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/support/faq_screen.dart';

void main() {
  Widget wrap(Widget screen) =>
      MaterialApp(theme: buildAppTheme(), home: screen);

  testWidgets('shows all FAQ sections', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    expect(find.text('USING THE APP'), findsOneWidget);
    // The list builds lazily, so scroll each later section into view.
    const laterSections = [
      'PREMIUM & BILLING',
      'THERAPY SESSIONS',
      'PRIVACY & YOUR DATA',
      'YOUR ACCOUNT',
    ];
    for (final label in laterSections) {
      await tester.scrollUntilVisible(find.text(label), 300);
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('tapping a question reveals its answer', (tester) async {
    await tester.pumpWidget(wrap(const FaqScreen()));

    final question = find.text('Who can read my journal?');
    await tester.scrollUntilVisible(question, 300);
    expect(find.textContaining('row-level security'), findsNothing);

    await tester.tap(question);
    await tester.pumpAndSettle();
    expect(find.textContaining('row-level security'), findsOneWidget);
  });

  testWidgets('contact card copies the support email', (tester) async {
    final clipboardCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        clipboardCalls.add(call);
        return null;
      },
    );
    await tester.pumpWidget(wrap(const FaqScreen()));

    final card = find.text('Still need help?');
    await tester.scrollUntilVisible(card, 400);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(
      clipboardCalls.map((c) => c.method),
      contains('Clipboard.setData'),
    );
    expect(find.text('Email address copied.'), findsOneWidget);
  });
}
