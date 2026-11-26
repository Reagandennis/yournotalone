// Renders the store-listing pictures: a coloured backdrop with soft waves,
// a two-tone headline and a real app screen in a phone, in two sizes — the
// App Store's 6.9" iPhone (1290 × 2796) and Google Play's phone (1080 ×
// 1920). Not a test: the name keeps it out of `flutter test`'s default run.
// Run with:
//   flutter test test/preview_store_listing.dart
// (add --dart-define=ONLY=sleep for one picture). The pictures land in
// build/store_listing/app_store/ and build/store_listing/play/.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/billing/purchases_service.dart';
import 'package:yournotalone/brand.dart';
import 'package:yournotalone/cbt/cbt_screen.dart';
import 'package:yournotalone/home/home_shell.dart';
import 'package:yournotalone/home/mood_face.dart';
import 'package:yournotalone/home/mood_scale.dart';
import 'package:yournotalone/journal/journal_hub_screen.dart';
import 'package:yournotalone/meditation/meditation_catalog.dart';
import 'package:yournotalone/meditation/meditation_screen.dart';
import 'package:yournotalone/sounds/player_screen.dart';
import 'package:yournotalone/sounds/sound_player.dart';
import 'package:yournotalone/sounds/sounds_catalog.dart';
import 'package:yournotalone/therapy/country_signals.dart';
import 'package:yournotalone/therapy/therapy_art.dart';
import 'package:yournotalone/therapy/therapy_repository.dart';
import 'package:yournotalone/therapy/therapy_screen.dart';
import 'package:yournotalone/toolkit/toolkit_art.dart';

const _only = String.fromEnvironment('ONLY');

// ── Sizes ──────────────────────────────────────────────────────────────
// Every picture is laid out 430 points wide; the height follows the store.

const _width = 430.0;

const _targets = [
  // App Store, 6.9" iPhone: the size every iPhone listing needs.
  ('app_store', 1290, 2796),
  // Google Play phone, 9:16 — the shape Play features.
  ('play', 1080, 1920),
];

// ── Colours ────────────────────────────────────────────────────────────

const _navy = Color(0xFF1A2238);
const _paper = Color(0xFFF8F5F0);
const _sun = Color(0xFFFFC940);

// ── A priced therapy screen, as in the other pictures ───────────────────

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

// ── One picture ────────────────────────────────────────────────────────

class _Slide {
  const _Slide({
    required this.name,
    required this.background,
    required this.waves,
    required this.ink,
    required this.highlight,
    required this.headline,
    this.screen,
    this.darkScreen = false,
    this.statusInk = _navy,
    this.body,
    this.mirror = false,
    this.stars = false,
  });

  final String name;
  final Color background;

  /// The wave bands, back to front.
  final List<Color> waves;
  final Color ink;
  final Color highlight;

  /// The headline, a part at a time; the parts in `*stars*` are
  /// highlighted.
  final String headline;

  /// The app screen in the phone. A picture without one has a [body].
  final Widget Function()? screen;
  final bool darkScreen;
  final Color statusInk;
  final Widget Function(double height)? body;

  /// Waves the other way round, so neighbouring pictures differ.
  final bool mirror;

  /// A night sky behind it.
  final bool stars;
}

/// Soft bands of colour across the picture, each a little deeper than the
/// one behind.
class _WavesPainter extends CustomPainter {
  const _WavesPainter(this.colors, {this.mirror = false, this.stars = false});

  final List<Color> colors;
  final bool mirror;
  final bool stars;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (mirror) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    if (stars) _stars(canvas, size);
    // Where each band starts on the left and ends on the right, and how
    // far its middle rises and dips — as a share of the height.
    const shapes = [
      (0.27, 0.19, -0.08, 0.07),
      (0.50, 0.40, -0.07, 0.08),
      (0.74, 0.66, -0.05, 0.06),
    ];
    for (var i = 0; i < colors.length; i++) {
      final (start, end, rise, dip) = shapes[i + (3 - colors.length)];
      final path = Path()
        ..moveTo(0, h * start)
        ..cubicTo(
          w * 0.32,
          h * (start + rise),
          w * 0.62,
          h * (end + dip),
          w,
          h * end,
        )
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[i]);
    }
  }

  void _stars(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 46; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.5;
      final r = 0.6 + rnd.nextDouble() * 1.3;
      paint.color = Colors.white.withValues(alpha: 0.25 + rnd.nextDouble() * 0.5);
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavesPainter old) => false;
}

/// A four-pointed sparkle, like the ones in the app's toolkit art.
class _Spark extends StatelessWidget {
  const _Spark({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SparkPainter(color));
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    const pinch = 0.26;
    final path = Path()..moveTo(c.dx, c.dy - r);
    for (final (dx, dy, px, py) in const [
      (1.0, 0.0, 1.0, -1.0),
      (0.0, 1.0, 1.0, 1.0),
      (-1.0, 0.0, -1.0, 1.0),
      (0.0, -1.0, -1.0, -1.0),
    ]) {
      path.quadraticBezierTo(
        c.dx + px * r * pinch,
        c.dy + py * r * pinch,
        c.dx + dx * r,
        c.dy + dy * r,
      );
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.color != color;
}

/// The headline, with its `*starred*` part in the highlight colour.
class _Headline extends StatelessWidget {
  const _Headline(this.text, {required this.ink, required this.highlight, this.size = 35});

  final String text;
  final Color ink;
  final Color highlight;
  final double size;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('*');
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: TextStyle(color: i.isOdd ? highlight : ink),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.14,
        letterSpacing: -0.9,
        decoration: TextDecoration.none,
      ),
    );
  }
}

/// A phone: a light bezel round a real app screen, 390 × 844 points
/// inside, scaled to fit.
class _Phone extends StatelessWidget {
  const _Phone({
    required this.width,
    required this.child,
    required this.dark,
    required this.statusInk,
  });

  final double width;
  final Widget child;
  final bool dark;
  final Color statusInk;

  static const screen = Size(390, 844);
  static const bezel = 9.0;

  @override
  Widget build(BuildContext context) {
    final inner = width - bezel * 2;
    final height = inner * screen.height / screen.width + bezel * 2;
    final theme = buildAppTheme(dark ? Brightness.dark : Brightness.light);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(bezel),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCFA),
        borderRadius: BorderRadius.circular(52),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33101828),
            blurRadius: 40,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(52 - bezel),
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: SizedBox.fromSize(
            size: screen,
            child: MediaQuery(
              data: const MediaQueryData(
                size: screen,
                devicePixelRatio: 3,
                padding: EdgeInsets.only(top: 50, bottom: 30),
                viewPadding: EdgeInsets.only(top: 50, bottom: 30),
              ),
              child: MaterialApp(
                theme: theme,
                debugShowCheckedModeBanner: false,
                home: Stack(
                  children: [
                    Positioned.fill(child: child),
                    Positioned(
                      left: 34,
                      right: 28,
                      top: 17,
                      child: _StatusBar(color: statusInk),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '9:41',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: color,
            decoration: TextDecoration.none,
          ),
        ),
        const Spacer(),
        Icon(Icons.signal_cellular_alt_rounded, size: 17, color: color),
        const SizedBox(width: 5),
        Icon(Icons.wifi_rounded, size: 17, color: color),
        const SizedBox(width: 5),
        Icon(Icons.battery_full_rounded, size: 17, color: color),
      ],
    );
  }
}

/// A whole picture, [height] points tall.
class _Picture extends StatelessWidget {
  const _Picture(this.slide, {required this.height});

  final _Slide slide;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Pictures for Play are shorter: the space above the phone shrinks a
    // little, the phone runs further off the bottom.
    final tall = height > 800;
    return SizedBox(
      width: _width,
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: ColoredBox(color: slide.background)),
          Positioned.fill(
            child: CustomPaint(
              painter: _WavesPainter(
                slide.waves,
                mirror: slide.mirror,
                stars: slide.stars,
              ),
            ),
          ),
          if (slide.body case final body?)
            Positioned.fill(child: body(height))
          else ...[
            Positioned(
              top: tall ? 74 : 52,
              left: 30,
              right: 30,
              child: _Headline(
                slide.headline,
                ink: slide.ink,
                highlight: slide.highlight,
              ),
            ),
            Positioned(
              top: tall ? 214 : 176,
              left: 0,
              right: 0,
              child: Center(
                child: _Phone(
                  width: 348,
                  dark: slide.darkScreen,
                  statusInk: slide.statusInk,
                  child: slide.screen!(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── The first two pictures, which have no phone ─────────────────────────

/// A gentle navy hill along the bottom, with a sand-coloured one behind.
class _HillPainter extends CustomPainter {
  const _HillPainter();

  /// Where the front hill's top is at [x], for a picture [size].
  static double crest(Size size, double x) {
    final t = x / size.width;
    final h = size.height;
    final edge = h * 0.85;
    final peak = h * 0.745;
    return (1 - t) * (1 - t) * edge + 2 * t * (1 - t) * peak + t * t * edge;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final back = Path()
      ..moveTo(0, h * 0.70)
      ..cubicTo(w * 0.30, h * 0.64, w * 0.62, h * 0.80, w, h * 0.72)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = const Color(0xFFFFE7A6));
    final front = Path()
      ..moveTo(0, h * 0.85)
      ..quadraticBezierTo(w / 2, h * 0.745, w, h * 0.85)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(front, Paint()..color = _navy);
  }

  @override
  bool shouldRepaint(covariant _HillPainter old) => false;
}

/// The logo, the name, the promise, and the mood faces on a hill.
Widget _brandBody(double height) {
  final tall = height > 800;
  final size = Size(_width, height);
  // Mood, size, and where its middle stands across the picture.
  final grow = tall ? 1.22 : 1.0;
  final faces = [
    (0, 64.0 * grow, 0.13),
    (1, 74.0 * grow, 0.30),
    (2, 90.0 * grow, 0.5),
    (3, 74.0 * grow, 0.70),
    (4, 64.0 * grow, 0.87),
  ];
  return Stack(
    children: [
      const Positioned.fill(child: CustomPaint(painter: _HillPainter())),
      for (final (level, side, at) in faces)
        Positioned(
          left: _width * at - side / 2,
          top: _HillPainter.crest(size, _width * at) - side + side * 0.08,
          child: MoodFace(level: moodLevels[level], size: side),
        ),
      Positioned(
        top: tall ? 78 : 50,
        left: 0,
        right: 0,
        child: Column(
          children: [
            Image.asset('assets/brand/pillars.png', height: tall ? 168 : 124),
            SizedBox(height: tall ? 18 : 12),
            const Text(
              'yournotalone',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
                color: _navy,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            const PillarStripe(width: 120, height: 5),
            SizedBox(height: tall ? 64 : 34),
            const _Headline(
              'You\'re *not alone.*',
              ink: _navy,
              highlight: Pillars.blue,
              size: 46,
            ),
            const SizedBox(height: 14),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 44),
              child: Text(
                'Calm, sleep and real support — for the heavy days and the '
                'good ones.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  height: 1.45,
                  color: Color(0xFF5E6576),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: tall ? 46 : 30,
        child: const Text(
          'Meditate · Sleep · CBT · Journal · Therapy',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    ],
  );
}

/// A tile for one part of the app, with its drawing.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.color,
    required this.ink,
    required this.art,
  });

  final String label;
  final Color color;
  final Color ink;
  final Widget art;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26101828),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -6, top: -4, child: art),
          Positioned(
            left: 18,
            bottom: 16,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: ink,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _gridBody(double height) {
  final tall = height > 800;
  // The art is drawn for the app's light cards, so it sits on a pale disc
  // where the tile is a deep colour.
  Widget art(ToolkitArtKind kind, {Color? disc}) => SizedBox(
    width: 104,
    height: 104,
    child: Stack(
      alignment: Alignment.center,
      children: [
        if (disc != null)
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
          ),
        ToolkitArt(kind: kind, size: 84),
      ],
    ),
  );
  final gap = tall ? 16.0 : 12.0;
  final tiles = [
    _Tile(
      label: 'Meditate',
      color: Pillars.blue,
      ink: Colors.white,
      art: art(ToolkitArtKind.sigh, disc: const Color(0x33FFFFFF)),
    ),
    _Tile(
      label: 'Sleep',
      color: const Color(0xFF10284D),
      ink: Colors.white,
      art: art(ToolkitArtKind.moon, disc: const Color(0x22FFFFFF)),
    ),
    _Tile(
      label: 'Thoughts',
      color: Pillars.red,
      ink: Colors.white,
      art: art(ToolkitArtKind.thoughts, disc: const Color(0x40FFFFFF)),
    ),
    _Tile(
      label: 'Stress',
      color: _paper,
      ink: _navy,
      art: art(ToolkitArtKind.gauge),
    ),
    _Tile(
      label: 'Journal',
      color: const Color(0xFFF7C4B4),
      ink: _navy,
      art: art(ToolkitArtKind.diary),
    ),
    _Tile(
      label: 'Therapy',
      color: const Color(0xFF2E7D4A),
      ink: Colors.white,
      art: Container(
        width: 118,
        height: 96,
        margin: const EdgeInsets.only(top: 10, right: 6),
        child: const TherapyArt(height: 96),
      ),
    ),
  ];
  return Column(
    children: [
      SizedBox(height: tall ? 74 : 52),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 30),
        child: _Headline(
          'Small steps to\n*a calmer mind*',
          ink: _navy,
          highlight: Color(0xFFB3261E),
        ),
      ),
      SizedBox(height: tall ? 52 : 30),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 26),
        child: Column(
          children: [
            for (var row = 0; row < 3; row++) ...[
              if (row > 0) SizedBox(height: gap),
              Row(
                children: [
                  Expanded(child: tiles[row * 2]),
                  SizedBox(width: gap),
                  Expanded(child: tiles[row * 2 + 1]),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// Sparkles scattered over a slide, for the calm and night pictures: in
/// the corners and the gap above the phone, clear of the headline.
Widget _sparkles(Color color, {required bool tall}) => IgnorePointer(
  child: Stack(
    children: [
      Positioned(left: 22, top: tall ? 34 : 22, child: _Spark(size: 18, color: color)),
      Positioned(right: 26, top: tall ? 178 : 146, child: _Spark(size: 22, color: color)),
      Positioned(left: 40, top: tall ? 182 : 150, child: _Spark(size: 11, color: color)),
    ],
  ),
);

// ── The set ────────────────────────────────────────────────────────────

Sound _sound(String title) =>
    soundsCatalog.firstWhere((s) => s.title == title);

final _slides = <_Slide>[
  _Slide(
    name: '01_brand',
    background: _paper,
    waves: const [],
    ink: _navy,
    highlight: Pillars.blue,
    headline: '',
    body: _brandBody,
  ),
  _Slide(
    name: '02_toolkit',
    background: const Color(0xFFFFD25E),
    waves: const [Color(0xFFFFC53A), Pillars.yellow, Color(0xFFF2A50C)],
    ink: _navy,
    highlight: const Color(0xFFB3261E),
    headline: '',
    body: _gridBody,
    mirror: true,
  ),
  _Slide(
    name: '03_check_in',
    background: const Color(0xFFE3EBFA),
    waves: const [Color(0xFFCFDCF6), Color(0xFFB4C9F1), Color(0xFF8EAEEA)],
    ink: _navy,
    highlight: Pillars.blue,
    headline: 'Check in with\n*how you feel*',
    screen: () => HomeShell(therapyPrice: () async => _kenya),
  ),
  _Slide(
    name: '04_meditate',
    background: Pillars.blue,
    waves: const [Color(0xFF4A76D8), Color(0xFF2F59BC), Color(0xFF2A4FA8)],
    ink: Colors.white,
    highlight: _sun,
    headline: 'Breathe easier\nin *a few minutes*',
    screen: () => MeditationScreen(meditation: meditations[1]),
    mirror: true,
  ),
  _Slide(
    name: '05_sleep',
    background: const Color(0xFF001939),
    waves: const [Color(0xFF0B2448), Color(0xFF10284D), Color(0xFF183460)],
    ink: Colors.white,
    highlight: _sun,
    headline: 'Wind down\nand *drift off*',
    screen: () => PlayerScreen(sound: _sound('Rainfall')),
    darkScreen: true,
    statusInk: Colors.white,
    stars: true,
  ),
  _Slide(
    name: '06_therapy',
    background: const Color(0xFF2E7D4A),
    waves: const [Color(0xFF3A8C57), Color(0xFF29723F), Color(0xFF236538)],
    ink: Colors.white,
    highlight: _sun,
    headline: 'Talk to a\n*licensed therapist*',
    screen: () => TherapyScreen(
      repository: _Kenya(),
      readCountrySignals: () async => const CountrySignals(),
    ),
    mirror: true,
  ),
  _Slide(
    name: '07_thoughts',
    background: const Color(0xFFC8352B),
    waves: const [Color(0xFFD5473C), Color(0xFFB92E25), Color(0xFFA6281F)],
    ink: Colors.white,
    highlight: const Color(0xFFFFD25E),
    headline: 'Untangle\n*anxious thoughts*',
    screen: () => const CbtScreen(),
    statusInk: Colors.white,
  ),
  _Slide(
    name: '08_journal',
    background: const Color(0xFFFFF3DC),
    waves: const [Color(0xFFFFE6B0), Color(0xFFFFD46A), Pillars.yellow],
    ink: _navy,
    highlight: const Color(0xFFC8352B),
    headline: 'Put the day\n*into words*',
    screen: () => const JournalHubScreen(),
    mirror: true,
  ),
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
    await _fonts();
    // Shown as a member sees it: no padlocks on the tools.
    PurchasesService.instance.isPro.value = true;
  });

  for (final (store, pxWide, pxHigh) in _targets) {
    for (final slide in _slides) {
      if (_only.isNotEmpty && !slide.name.contains(_only)) continue;
      testWidgets('store listing: $store ${slide.name}', (tester) async {
        final ratio = pxWide / _width;
        final height = pxHigh / ratio;
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = Size(pxWide.toDouble(), pxHigh.toDouble());
        addTearDown(tester.view.reset);
        // Each picture starts in silence: the sleep picture's sound would
        // otherwise carry into the meditation that follows.
        addTearDown(SoundPlayer.instance.stop);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: buildAppTheme(),
              debugShowCheckedModeBanner: false,
              home: Material(
                type: MaterialType.transparency,
                child: Stack(
                  children: [
                    _Picture(slide, height: height),
                    if (slide.name == '04_meditate')
                      _sparkles(const Color(0x66FFFFFF), tall: height > 800),
                    if (slide.name == '05_sleep')
                      _sparkles(const Color(0xCCFFC940), tall: height > 800),
                  ],
                ),
              ),
            ),
          ),
        );
        // Pictures (the logo, Home's sunrise) decode off the fake clock.
        await tester.runAsync(() async {
          final context = key.currentContext!;
          await precacheImage(
            const AssetImage('assets/brand/pillars.png'),
            context,
          );
          await precacheImage(
            const AssetImage('assets/rhythm/sunrise.jpg'),
            context,
          );
          await Future<void>.delayed(const Duration(milliseconds: 400));
        });
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        // Some pictures are only asked for once their card's data is in
        // (Home's sunrise): a second real pause lets them decode.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 600)),
        );
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        final error = tester.takeException();
        if (error != null) debugPrint('${slide.name}: $error');
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: ratio);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = Directory('build/store_listing/$store')
            ..createSync(recursive: true);
          File(
            '${out.path}/${slide.name}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
        });
      });
    }
  }
}
