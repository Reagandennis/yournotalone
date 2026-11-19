// Renders the store-style picture of the therapy screen (1080 × 1920: a title,
// the pillar stripe and the screen in a phone outline), as used on the
// website (yournotalone-web/assets/screenshots/02_therapy.png) and the store
// listings. Not a test: the name keeps it out of `flutter test`'s default
// run. Run with:
//   flutter test test/preview_store_therapy.dart --update-goldens
// The picture lands in test/store_02_therapy.png.
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

class _Kenya extends TherapyRepository {
  static final _quote = TherapyPriceQuote.fromJson(const {
    'country': 'KE',
    'source': 'zone',
    'locked': false,
    'can_change': false,
    'currency': 'KES',
    'price_minor': 260000,
    'charge_currency': 'KES',
    'charge_minor': 260000,
  });

  @override
  Future<TherapyPriceQuote> detectPriceCountry(CountrySignals signals) async =>
      _quote;

  @override
  Future<TherapyPriceQuote> fetchPriceQuote() async => _quote;

  @override
  Future<List<TherapyRequest>> fetchRequests() async => const [];

  @override
  Future<Map<String, TherapistProfile>> fetchTherapists(
    Iterable<String> ids,
  ) async => const {};

  @override
  Future<Map<String, int>> fetchMyRatings() async => const {};
}

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
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer))))
        .load();
  }
}

/// The phone's own top bar, as in the other store pictures.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF191919);
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 10, 22, 4),
      child: Row(
        children: [
          Text(
            '8:23',
            style: TextStyle(fontSize: 13, color: ink, fontFamily: 'Poppins'),
          ),
          Spacer(),
          Icon(Icons.signal_cellular_alt_rounded, size: 15, color: ink),
          SizedBox(width: 4),
          Icon(Icons.wifi_rounded, size: 15, color: ink),
          SizedBox(width: 4),
          Icon(Icons.battery_full_rounded, size: 15, color: ink),
        ],
      ),
    );
  }
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

  testWidgets('store picture: therapy', (tester) async {
    // 540 × 960 points at 2x: 1080 × 1920 pixels.
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(1080, 1920);
    addTearDown(tester.view.reset);

    final theme = buildAppTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        debugShowCheckedModeBanner: false,
        home: Material(
          color: Colors.white,
          child: Column(
            children: [
              const SizedBox(height: 44),
              const Text(
                'A real therapist, one tap away',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 31,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191919),
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
              const PillarStripe(),
              const SizedBox(height: 44),
              Container(
                width: 346,
                height: 770,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: const Color(0xFFE2E2E6), width: 1.5),
                ),
                child: Column(
                  children: [
                    const _StatusBar(),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: 390,
                          height: 820,
                          child: MediaQuery(
                            data: const MediaQueryData(size: Size(390, 820)),
                            child: TherapyScreen(
                              repository: _Kenya(),
                              readCountrySignals: () async =>
                                  const CountrySignals(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    // Past the picture, so the price card sits in the middle of the screen.
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('store_02_therapy.png'),
    );
  });
}
