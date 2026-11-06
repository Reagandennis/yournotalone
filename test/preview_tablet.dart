// Renders the main screens at tablet and foldable sizes, with the real
// Poppins font, to PNGs for looking at without a device. Not a test of
// anything — the name keeps it out of `flutter test`'s default run. Run:
//   flutter test test/preview_tablet.dart --dart-define=PREVIEW_OUT=<dir>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/cbt/cbt_screen.dart';
import 'package:yournotalone/home/home_shell.dart';
import 'package:yournotalone/journal/journal_hub_screen.dart';
import 'package:yournotalone/meditation/breathing_screen.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/meditation/meditations_screen.dart';
import 'package:yournotalone/recovery/recovery_screen.dart';
import 'package:yournotalone/sounds/player_screen.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';
import 'package:yournotalone/sounds/sounds_screen.dart';

const _out = String.fromEnvironment('PREVIEW_OUT', defaultValue: 'build/preview');
const _only = String.fromEnvironment('PREVIEW_ONLY');

const _sizes = [
  ('ipad-landscape', Size(1366, 1024)),
  ('ipad-portrait', Size(1024, 1366)),
  ('ipad-mini', Size(744, 1133)),
  ('duo-open', Size(620, 1130)),
  ('duo-open-sideways', Size(1130, 620)),
];

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
    final loader = FontLoader('Poppins');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  final screens = <String, Widget Function()>{
    'home': () => const HomeShell(),
    'explore': () => const HomeShell(),
    'settings': () => const HomeShell(),
    'sounds': () => const SoundsScreen(),
    'meditations': () => const MeditationsScreen(),
    'recovery': () => const RecoveryScreen(),
    'journal': () => const JournalHubScreen(),
    'cbt': () => const CbtScreen(),
    'player': () => PlayerScreen(sound: soundsCatalog.first),
    'breathing': () => BreathingScreen(pattern: breathPatterns.first),
  };

  for (final (label, size) in _sizes) {
    for (final entry in screens.entries) {
      final name = '${entry.key}-$label';
      if (_only.isNotEmpty && !name.contains(_only)) continue;
      testWidgets(name, (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: buildAppTheme(),
            debugShowCheckedModeBanner: false,
            home: entry.value(),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 500));
        final tab = {'explore': 1, 'settings': 2}[entry.key];
        if (tab != null) {
          homeTabRequest.value = tab;
          await tester.pump(const Duration(milliseconds: 500));
        }
        final error = tester.takeException();
        if (error != null) debugPrint('$name: $error');
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(_out).createSync(recursive: true);
          File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
