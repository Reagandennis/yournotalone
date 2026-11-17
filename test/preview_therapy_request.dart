// Renders the therapy screen and the three steps of asking for a session,
// with the real Poppins and icon fonts, to PNGs for looking at them without
// a device. Not a test of anything: the name keeps it out of `flutter
// test`'s default run. Run with:
//   flutter test test/preview_therapy_request.dart --update-goldens
// The pictures land in test/therapy_request_*.png.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/therapy/country_signals.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';
import 'package:yournotalone/therapy/therapy_screen.dart';

class _Priced extends TherapyRepository {
  _Priced(this.quote);

  final Map<String, dynamic> quote;

  @override
  Future<TherapyPriceQuote> detectPriceCountry(CountrySignals signals) async =>
      TherapyPriceQuote.fromJson(quote);

  @override
  Future<TherapyPriceQuote> fetchPriceQuote() async =>
      TherapyPriceQuote.fromJson(quote);

  @override
  Future<List<TherapyRequest>> fetchRequests() async => const [];

  @override
  Future<Map<String, TherapistProfile>> fetchTherapists(
    Iterable<String> ids,
  ) async => const {};

  @override
  Future<Map<String, int>> fetchMyRatings() async => const {};
}

const _kenya = {
  'country': 'KE',
  'source': 'store',
  'locked': false,
  'can_change': false,
  'currency': 'KES',
  'price_minor': 260000,
  'charge_currency': 'KES',
  'charge_minor': 260000,
};

const _uk = {
  'country': 'GB',
  'source': 'store',
  'locked': false,
  'can_change': false,
  'currency': 'GBP',
  'price_minor': 4000,
  'charge_currency': 'KES',
  'charge_minor': 687000,
};

Future<void> _fonts() async {
  final poppins = FontLoader('Poppins');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    poppins.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
  }
  await poppins.load();
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer)));
    await loader.load();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _shoot(WidgetTester tester, String name) => expectLater(
  find.byType(MaterialApp),
  matchesGoldenFile('therapy_request_$name.png'),
);

Future<void> _open(
  WidgetTester tester,
  Map<String, dynamic> quote, {
  double height = 844,
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = Size(390 * 2, height * 2);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: mode,
      debugShowCheckedModeBanner: false,
      home: TherapyScreen(
        repository: _Priced(quote),
        readCountrySignals: () async => const CountrySignals(),
      ),
    ),
  );
  await _settle(tester);
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
    await _fonts();
  });

  testWidgets('the therapy screen', (tester) async {
    await _open(tester, _kenya, height: 1500);
    await _shoot(tester, '0_screen');
  });

  testWidgets('the three steps', (tester) async {
    await _open(tester, _uk);
    await tester.tap(find.text('Request a session'));
    await _settle(tester);
    await tester.tap(find.text('Anxiety & stress'));
    await _settle(tester);
    await _shoot(tester, '1_topic');
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Weekday evenings'));
    await tester.tap(find.text('Weekends'));
    await tester.enterText(
      find.byType(TextField),
      'Work has been a lot lately and I\'m not sleeping well.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(tester);
    await _shoot(tester, '2_when');
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await _shoot(tester, '3_review');
  });

  testWidgets('the review, dark', (tester) async {
    await _open(tester, _uk, mode: ThemeMode.dark);
    await tester.tap(find.text('Request a session'));
    await _settle(tester);
    await tester.tap(find.text('Low mood'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await tester.tap(find.text('Continue'));
    await _settle(tester);
    await _shoot(tester, '4_review_dark');
  });
}
