import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The logo's four pillar colours, exactly as drawn. They never change
/// with light or dark mode.
///
/// Use them as they are for the logo, and for solid fills that carry their
/// own white text (a blue button, a red card). Content declared once — a
/// catalogue entry, a mood — also names its accent with one of these; it
/// is then drawn on screen through [BrandColors.accent] or
/// [BrandColors.tint], which pick the right shade for the mode.
abstract final class Pillars {
  static const red = Color(0xFFE12D23);
  static const blue = Color(0xFF3764CD);
  static const black = Color(0xFF191919);
  static const yellow = Color(0xFFFAB414);
}

/// The app's colours for one mode — "Paper & Navy". Read them with
/// `context.brand`.
///
/// Light mode is navy-ink on warm paper, with white cards that lift off the
/// page. Dark mode is built on the navy of the dark-mode logo, with the
/// pillar colours lightened so they read on it, and the black pillar turned
/// white, as it is on that logo.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors._({
    required this.brightness,
    required this.background,
    required this.card,
    required this.sheet,
    required this.chip,
    required this.ink,
    required this.onInk,
    required this.textMuted,
    required this.border,
    required this.red,
    required this.blue,
    required this.yellow,
    required this.green,
  });

  static const light = BrandColors._(
    brightness: Brightness.light,
    background: Color(0xFFF8F5F0),
    card: Color(0xFFFFFFFF),
    sheet: Color(0xFFFFFFFF),
    chip: Color(0xFFFFFFFF),
    ink: Color(0xFF1A2238),
    onInk: Color(0xFFFFFFFF),
    textMuted: Color(0xFF5E6576),
    border: Color(0xFFE6E1D9),
    red: Color(0xFFC8352B),
    blue: Color(0xFF3764CD),
    yellow: Color(0xFF946200),
    green: Color(0xFF2E7D4A),
  );

  static const dark = BrandColors._(
    brightness: Brightness.dark,
    background: Color(0xFF001939),
    card: Color(0xFF10284D),
    sheet: Color(0xFF183460),
    chip: Color(0x17FFFFFF),
    ink: Color(0xFFEEF1F6),
    onInk: Color(0xFF001939),
    textMuted: Color(0xFFA3AEC2),
    border: Color(0xFF1E3A63),
    red: Color(0xFFFF6F61),
    blue: Color(0xFF86A8F2),
    yellow: Color(0xFFFFC940),
    green: Color(0xFF6CC68A),
  );

  final Brightness brightness;

  /// Behind every screen.
  final Color background;

  /// Cards, tiles, the tab bar — anything that sits on the page.
  final Color card;

  /// Dialogs and bottom sheets, which sit above the page.
  final Color sheet;

  /// The small round icon holder inside a tinted card.
  final Color chip;

  /// Main text, and the fill of the main button.
  final Color ink;

  /// Text and icons on an [ink] fill.
  final Color onInk;

  final Color textMuted;
  final Color border;

  /// Pillar colours as text, icons and lines on the page — never as a fill
  /// behind white text, which is what [Pillars] is for. [red] is also the
  /// error colour; [yellow] is the readable one, so a dark amber in light
  /// mode.
  final Color red;
  final Color blue;
  final Color yellow;
  final Color green;

  bool get isDark => brightness == Brightness.dark;

  /// The pillar stripe and other logo-like accents, in logo order: red,
  /// blue, black, yellow.
  List<Color> get pillars => isDark
      ? [red, blue, ink, yellow]
      : const [Pillars.red, Pillars.blue, Color(0xFF1A2238), Pillars.yellow];

  /// The four-pillar artwork. In the dark the black pillar is white.
  String get pillarsAsset =>
      isDark ? 'assets/brand/pillars_dark.png' : 'assets/brand/pillars.png';

  /// Status bar and Android navigation bar to match the page.
  SystemUiOverlayStyle get systemOverlayStyle =>
      (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: card,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      );

  /// [base] drawn as text, an icon or a line on the page.
  ///
  /// A pillar colour (or one of the app's few other accents) comes back as
  /// its designed shade for this mode; any other colour is shifted just far
  /// enough to read against [background] — darker in light mode, lighter in
  /// dark. Pass the colour content was declared with, e.g. a meditation's
  /// `Pillars.blue`.
  Color accent(Color base) {
    final key = base.withValues(alpha: 1).toARGB32();
    final designed = (isDark ? _darkAccents : _lightAccents)[key];
    final opaque = designed ?? _readable(key);
    return base.a == 1 ? opaque : opaque.withValues(alpha: base.a);
  }

  /// [base] as a fill in a drawing — a mood face, a pillar in a backdrop.
  /// As declared in light mode; in dark mode the lighter accent, so the
  /// shape still stands out from the navy.
  Color art(Color base) => isDark ? accent(base) : base;

  /// A soft wash of [base] for a card or tile background, at [alpha] in
  /// light mode. On navy the same wash needs more colour to show, so dark
  /// mode uses the lighter accent at nearly twice the strength — less for
  /// the bright ones (yellow, the off-white ink), which otherwise turn the
  /// navy olive or chalky.
  Color tint(Color base, [double alpha = 0.07]) {
    if (isDark) {
      final shade = accent(base);
      final boost = shade.computeLuminance() > 0.5 ? 1.3 : 1.8;
      return shade.withValues(alpha: math.min(alpha * boost, 1));
    }
    final solid = base.withValues(alpha: 1);
    return (solid == Pillars.black ? ink : solid).withValues(alpha: alpha);
  }

  static final _lightAccents = <int, Color>{
    Pillars.red.toARGB32(): light.red,
    Pillars.blue.toARGB32(): light.blue,
    Pillars.black.toARGB32(): light.ink,
    Pillars.yellow.toARGB32(): light.yellow,
    0xFF3E9B5B: light.green,
    0xFFEF7418: const Color(0xFFB4520A),
    0xFF5E8BDD: const Color(0xFF3F6AC6),
  };

  static final _darkAccents = <int, Color>{
    Pillars.red.toARGB32(): dark.red,
    Pillars.blue.toARGB32(): dark.blue,
    Pillars.black.toARGB32(): dark.ink,
    light.ink.toARGB32(): dark.ink,
    Pillars.yellow.toARGB32(): dark.yellow,
    0xFF3E9B5B: dark.green,
    light.green.toARGB32(): dark.green,
    0xFFEF7418: const Color(0xFFFF9A52),
    0xFF5E8BDD: const Color(0xFFA9C1F5),
  };

  static final _readableCache = <(Brightness, int), Color>{};

  /// Steps the lightness of [argb] until it has 4.5:1 contrast with the
  /// page — the WCAG level for body text.
  Color _readable(int argb) => _readableCache.putIfAbsent((brightness, argb), () {
        final page = background.computeLuminance();
        double contrast(Color c) {
          final l = c.computeLuminance();
          return (math.max(l, page) + 0.05) / (math.min(l, page) + 0.05);
        }

        var hsl = HSLColor.fromColor(Color(argb));
        for (var i = 0; i < 50 && contrast(hsl.toColor()) < 4.5; i++) {
          final step = isDark ? 0.02 : -0.02;
          hsl = hsl.withLightness((hsl.lightness + step).clamp(0.0, 1.0));
        }
        return hsl.toColor();
      });

  @override
  BrandColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? card,
    Color? sheet,
    Color? chip,
    Color? ink,
    Color? onInk,
    Color? textMuted,
    Color? border,
    Color? red,
    Color? blue,
    Color? yellow,
    Color? green,
  }) {
    return BrandColors._(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      card: card ?? this.card,
      sheet: sheet ?? this.sheet,
      chip: chip ?? this.chip,
      ink: ink ?? this.ink,
      onInk: onInk ?? this.onInk,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      red: red ?? this.red,
      blue: blue ?? this.blue,
      yellow: yellow ?? this.yellow,
      green: green ?? this.green,
    );
  }

  /// Colours blend while the theme animates between modes; the mode itself
  /// (which decides [accent] and [tint]) flips halfway.
  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrandColors._(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: mix(background, other.background),
      card: mix(card, other.card),
      sheet: mix(sheet, other.sheet),
      chip: mix(chip, other.chip),
      ink: mix(ink, other.ink),
      onInk: mix(onInk, other.onInk),
      textMuted: mix(textMuted, other.textMuted),
      border: mix(border, other.border),
      red: mix(red, other.red),
      blue: mix(blue, other.blue),
      yellow: mix(yellow, other.yellow),
      green: mix(green, other.green),
    );
  }
}

extension BrandContext on BuildContext {
  /// The app's colours for the current mode. Falls back to the plain
  /// light or dark set under a theme that wasn't built by [buildAppTheme],
  /// as in some tests.
  BrandColors get brand {
    final theme = Theme.of(this);
    return theme.extension<BrandColors>() ??
        (theme.brightness == Brightness.dark
            ? BrandColors.dark
            : BrandColors.light);
  }
}

/// The four pillar colours as a slim rounded stripe — the accent motif
/// used under headings throughout the app.
class PillarStripe extends StatelessWidget {
  const PillarStripe({super.key, this.width = 132, this.height = 5});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        // Stretch, or the bars take their child-less height of zero.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, color) in context.brand.pillars.indexed) ...[
            if (i != 0) SizedBox(width: height * 0.8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// App-wide theme: Poppins everywhere, navy-ink on paper (or off-white on
/// navy), with the pillar colours as accents.
ThemeData buildAppTheme([Brightness brightness = Brightness.light]) {
  final c = brightness == Brightness.dark ? BrandColors.dark : BrandColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Pillars.blue,
    brightness: brightness,
  ).copyWith(
    surface: c.card,
    onSurface: c.ink,
    onSurfaceVariant: c.textMuted,
    surfaceContainerLowest: c.card,
    surfaceContainerLow: c.card,
    surfaceContainer: c.card,
    surfaceContainerHigh: c.sheet,
    surfaceContainerHighest: c.sheet,
    error: c.red,
    outline: c.border,
    outlineVariant: c.border,
  );
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    extensions: [c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: c.systemOverlayStyle,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
    ),
    iconTheme: IconThemeData(color: c.ink),
    dividerTheme: DividerThemeData(color: c.border),
    cardTheme: CardThemeData(color: c.card, surfaceTintColor: Colors.transparent),
    listTileTheme: ListTileThemeData(iconColor: c.textMuted, textColor: c.ink),
    inputDecorationTheme: InputDecorationThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: TextStyle(
        color: c.textMuted,
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
      ),
      hintStyle: TextStyle(color: c.textMuted),
      floatingLabelStyle: TextStyle(color: c.ink, fontWeight: FontWeight.w500),
      prefixIconColor: c.textMuted,
      suffixIconColor: c.textMuted,
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: c.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: c.ink, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: c.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: c.red, width: 1.6),
      ),
      errorStyle: TextStyle(color: c.red, fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.ink,
        foregroundColor: c.onInk,
        disabledBackgroundColor: c.border,
        disabledForegroundColor: c.textMuted,
        minimumSize: const Size.fromHeight(56),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.blue,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.ink,
      selectionColor: c.blue.withValues(alpha: 0.2),
      selectionHandleColor: c.blue,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: c.tint(Pillars.black, 0.08),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color:
              states.contains(WidgetState.selected) ? c.ink : c.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color:
              states.contains(WidgetState.selected) ? c.ink : c.textMuted,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? c.onInk : c.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? c.ink
            : c.tint(Pillars.black, 0.08),
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : c.textMuted.withValues(alpha: 0.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.sheet,
      surfaceTintColor: Colors.transparent,
      // An AlertDialog is as wide as its longest line of text, up to the
      // screen less 40pt either side: fine on a phone, a 1300pt banner on
      // a landscape iPad. Phones never reach the cap.
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: c.ink,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: c.textMuted,
        height: 1.55,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      // Material 3's default, stated here because the tablet layout relies
      // on it: sheets stay a phone-like column on an iPad.
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: c.sheet,
      modalBackgroundColor: c.sheet,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: c.border,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.sheet,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      actionTextColor: c.isDark ? Pillars.blue : BrandColors.dark.blue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: c.onInk,
      ),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink),
  );
}
