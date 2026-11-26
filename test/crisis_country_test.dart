import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/support/crisis_resources.dart';
import 'package:yournotalone/support/crisis_screen.dart';
import 'package:yournotalone/support/heavy_day_sheet.dart';
import 'package:yournotalone/support/phone_country.dart';

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

  tearDown(() {
    CrisisCountrySetting.instance.debugDetected = null;
    CrisisCountrySetting.instance.value = null;
    debugTelephony = null;
  });

  group('a phone somewhere this build has no numbers for', () {
    test('gets the international list, not its language\'s country', () {
      // A Nigerian phone set to English (United States).
      CrisisCountrySetting.instance.debugDetected = 'NG';
      expect(crisisCountry(const [Locale('en', 'US')], false), isNull);
      expect(
        crisisRegionFor(crisisCountry(const [Locale('en', 'US')], false)),
        same(internationalRegion),
      );
    });

    test('a country picked on the crisis screen still wins', () {
      CrisisCountrySetting.instance.debugDetected = 'NG';
      CrisisCountrySetting.instance.value = 'US';
      expect(crisisCountry(const [Locale('en', 'GB')], false), 'US');
    });

    test('with nothing detected, the language\'s country is used', () {
      expect(crisisCountry(const [Locale('en', 'US')], false), 'US');
    });
  });

  group('where the phone is', () {
    test('crisis use reads the network first, prices the SIM first', () async {
      // A Kenyan SIM roaming in the UK.
      debugTelephony = (sim: 'ke', network: 'GB');
      expect(await networkCountry(), 'GB');
      expect(await simCountry(), 'KE');

      debugTelephony = (sim: null, network: 'GB');
      expect(await simCountry(), 'GB');
      debugTelephony = (sim: 'KE', network: null);
      expect(await networkCountry(), 'KE');
    });

    test('detect() uses the network country and tells listeners', () async {
      debugTelephony = (sim: 'KE', network: 'GB');
      var heard = 0;
      void listener() => heard++;
      CrisisCountrySetting.instance.addListener(listener);
      addTearDown(
        () => CrisisCountrySetting.instance.removeListener(listener),
      );
      await CrisisCountrySetting.instance.detect();
      expect(CrisisCountrySetting.instance.detected, 'GB');
      expect(heard, 1);
    });
  });

  group('a detection that lands after the screen opened', () {
    Widget wrap(Widget screen) =>
        MaterialApp(theme: buildAppTheme(), home: screen);

    testWidgets('moves the crisis screen to where the phone is', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 2400);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(const CrisisScreen()));
      expect(find.text('United States'), findsOneWidget);

      CrisisCountrySetting.instance.debugDetected = 'KE';
      await tester.pump();
      expect(find.text('Kenya'), findsOneWidget);
      expect(find.text('United States'), findsNothing);

      // Somewhere without numbers here: the international list, not 911.
      CrisisCountrySetting.instance.debugDetected = 'NG';
      await tester.pump();
      expect(find.textContaining('911'), findsNothing);
      expect(find.text(internationalRegion.label), findsOneWidget);
    });

    testWidgets('leaves a country the person picked alone', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 2400);
      addTearDown(tester.view.reset);
      CrisisCountrySetting.instance.value = 'GB';

      await tester.pumpWidget(wrap(const CrisisScreen()));
      expect(find.text('United Kingdom'), findsOneWidget);
      CrisisCountrySetting.instance.debugDetected = 'KE';
      await tester.pump();
      expect(find.text('United Kingdom'), findsOneWidget);
      expect(find.text('Kenya'), findsNothing);
    });

    testWidgets('updates the heavy-day sheet too', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 1600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showHeavyDaySheet(context),
              child: const Text('Awful'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Awful'));
      await tester.pumpAndSettle();
      expect(find.text('Numbers for United States'), findsOneWidget);

      CrisisCountrySetting.instance.debugDetected = 'KE';
      await tester.pump();
      expect(find.text('Numbers for Kenya'), findsOneWidget);
    });
  });
}
