import 'package:flutter/material.dart';

/// Brand palette drawn from the four pillars of the logo.
abstract final class Brand {
  static const ink = Color(0xFF191919);
  static const red = Color(0xFFE12D23);
  static const blue = Color(0xFF3764CD);
  static const yellow = Color(0xFFFAB414);

  static const textMuted = Color(0xFF6E6E73);
  static const border = Color(0xFFE5E5EA);

  /// In logo order: red, blue, black, yellow.
  static const pillarColors = [red, blue, ink, yellow];
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
          for (final (i, color) in Brand.pillarColors.indexed) ...[
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

/// App-wide theme: Poppins everywhere, ink-on-white like the logo, with
/// the pillar colours as accents.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.blue,
    surface: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    fontFamily: 'Poppins',
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Brand.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Brand.ink,
      ),
    ),
    inputDecorationTheme: const InputDecorationThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      labelStyle: TextStyle(
        color: Brand.textMuted,
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: TextStyle(color: Brand.ink, fontWeight: FontWeight.w500),
      prefixIconColor: Brand.textMuted,
      suffixIconColor: Brand.textMuted,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Brand.border, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Brand.ink, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Brand.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Brand.red, width: 1.6),
      ),
      errorStyle: TextStyle(color: Brand.red, fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Brand.ink,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Brand.border,
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
        foregroundColor: Brand.blue,
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
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Brand.ink,
      selectionColor: Color(0x333764CD),
      selectionHandleColor: Brand.blue,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      height: 68,
      indicatorColor: const Color(0x14191919),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? Brand.ink
              : Brand.textMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? Brand.ink
              : Brand.textMuted,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: Brand.ink,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: Brand.textMuted,
        height: 1.55,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Brand.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentTextStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: Colors.white,
      ),
    ),
  );
}
