import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/auth/login_screen.dart';
import 'package:yournotalone/auth/signup_screen.dart';

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

  // An iPhone-sized screen with the Apple button showing — the layout that
  // pushed "Create an account" below the fold.
  Future<void> pumpOnPhone(WidgetTester tester, Widget screen) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('login shows the way to sign up without scrolling',
      (tester) async {
    await pumpOnPhone(tester, const LoginScreen());
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Create an account').hitTestable(), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('signup shows the way back to log in without scrolling',
      (tester) async {
    await pumpOnPhone(tester, const SignupScreen());
    expect(find.text('Log in').hitTestable(), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
