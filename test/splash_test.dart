import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/splash_screen.dart';

void main() {
  Future<void> letSplashFinish(WidgetTester tester) async {
    // 2.6 s of animation, a 0.6 s pause, then a 0.45 s fade.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('the splash hands over to the next screen', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SplashScreen(next: Scaffold(body: Text('NEXT'))),
    ));
    await letSplashFinish(tester);
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('a screen pushed over the splash survives the handover',
      (tester) async {
    // A password-reset link opening the app pushes its screen while the
    // splash is still playing. The splash must swap itself out underneath,
    // not replace that screen.
    await tester.pumpWidget(const MaterialApp(
      home: SplashScreen(next: Scaffold(body: Text('NEXT'))),
    ));
    await tester.pump(const Duration(seconds: 1));
    final navigator = Navigator.of(tester.element(find.byType(SplashScreen)));
    navigator.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('ABOVE')),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ABOVE'), findsOneWidget);

    await letSplashFinish(tester);
    expect(find.text('ABOVE'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);

    // Leaving that screen lands on what the splash was heading for.
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('NEXT'), findsOneWidget);
  });

  testWidgets('a splash taken off the stack early stays quiet',
      (tester) async {
    // An expired session sends the app to login while the intro plays.
    await tester.pumpWidget(const MaterialApp(
      home: SplashScreen(next: Scaffold(body: Text('NEXT'))),
    ));
    await tester.pump(const Duration(seconds: 1));
    Navigator.of(tester.element(find.byType(SplashScreen))).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('LOGIN')),
      ),
      (_) => false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await letSplashFinish(tester);
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
