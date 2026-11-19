// Renders app screens the way the MindPillars website shows them (a phone's
// whole screen, 694 × 1541, with its status bar and gesture bar), priced
// for Kenya. Not a test: the name keeps it out of `flutter test`'s default
// run. Run with:
//   flutter test test/preview_site_phones.dart
// The pictures land in build/site_phones/; the website keeps them as WebP in
// src/assets/phones/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/home/home_shell.dart';
import 'package:yournotalone/therapy/country_signals.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';
import 'package:yournotalone/therapy/therapy_screen.dart';

final _kenya = TherapyPriceQuote.fromJson(const {
  'country': 'KE',
  'source': 'zone',
  'locked': false,
  'can_change': false,
  'currency': 'KES',
  'price_minor': 260000,
  'charge_currency': 'KES',
  'charge_minor': 260000,
});

class _Kenya extends TherapyRepository {
  @override
  Future<TherapyPriceQuote> detectPriceCountry(CountrySignals signals) async =>
      _kenya;

  @override
  Future<TherapyPriceQuote> fetchPriceQuote() async => _kenya;

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
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(icons.readAsBytesSync().buffer))))
      .load();
}

/// The phone's own bars around the app, as on the website's other screens.
class _Phone extends StatelessWidget {
  const _Phone({required this.child});

  final Widget child;

  static const top = 34.0;
  static const bottom = 22.0;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF191919);
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        padding: const EdgeInsets.only(top: top, bottom: bottom),
        viewPadding: const EdgeInsets.only(top: top, bottom: bottom),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: child),
          const Positioned(
            left: 22,
            right: 18,
            top: 9,
            child: Row(
              children: [
                Text(
                  '8:23',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: ink,
                    fontFamily: 'Poppins',
                    decoration: TextDecoration.none,
                  ),
                ),
                Spacer(),
                Icon(Icons.signal_cellular_alt_rounded, size: 15, color: ink),
                SizedBox(width: 4),
                Icon(Icons.wifi_rounded, size: 15, color: ink),
                SizedBox(width: 4),
                Icon(Icons.battery_full_rounded, size: 15, color: ink),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 108,
                height: 4,
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
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

  final screens = <String, Widget Function()>{
    'therapy': () => TherapyScreen(
      repository: _Kenya(),
      readCountrySignals: () async => const CountrySignals(),
    ),
    'home': () => HomeShell(therapyPrice: () async => _kenya),
    'home-quick': () => HomeShell(therapyPrice: () async => _kenya),
    if (const bool.fromEnvironment('TALL'))
      'home-tall': () => HomeShell(therapyPrice: () async => _kenya),
  };

  for (final entry in screens.entries) {
    testWidgets('site phone: ${entry.key}', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = Size(694, entry.key == 'home-tall' ? 5200 : 1541);
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: buildAppTheme(),
            debugShowCheckedModeBanner: false,
            home: Builder(builder: (context) => _Phone(child: entry.value())),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      if (entry.key == 'home-quick') {
        // Down to quick access and the therapist card, as the website's
        // picture of Home shows it.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
      }
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = Directory('build/site_phones')..createSync(recursive: true);
        File('${out.path}/${entry.key}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    });
  }
}
