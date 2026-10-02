import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yournotalone/appearance.dart';
import 'package:yournotalone/brand.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every accent the app declares content with, plus a couple it doesn't, so
/// the fallback path is covered too.
const _declared = [
  Pillars.red,
  Pillars.blue,
  Pillars.black,
  Pillars.yellow,
  Color(0xFF3E9B5B), // green
  Color(0xFFEF7418), // the Low mood
  Color(0xFF5E8BDD), // the Good mood
  Color(0xFFC53C26), // CBT and Explore red
  Color(0xFF3E6AB7), // sleep and Explore blue
  Color(0xFFF4BB40), // stress and Explore yellow
  Color(0xFF00C2A8),
  Color(0xFFFFEE00),
];

void main() {
  for (final c in [BrandColors.light, BrandColors.dark]) {
    final mode = c.isDark ? 'dark' : 'light';

    test('$mode text colours read on the page and on cards', () {
      final text = {
        'ink': c.ink,
        'textMuted': c.textMuted,
        'red': c.red,
        'blue': c.blue,
        'yellow': c.yellow,
        'green': c.green,
      };
      for (final surface in [c.background, c.card]) {
        for (final MapEntry(:key, :value) in text.entries) {
          expect(_contrast(value, surface), greaterThanOrEqualTo(4.5),
              reason: '$mode $key on $surface');
        }
      }
      expect(_contrast(c.onInk, c.ink), greaterThanOrEqualTo(4.5),
          reason: '$mode button label');
    });

    test('$mode accents are readable and settle on one shade', () {
      for (final base in _declared) {
        final shade = c.accent(base);
        expect(_contrast(shade, c.background), greaterThanOrEqualTo(4.5),
            reason: '$mode accent of $base');
        expect(c.accent(shade), shade, reason: '$mode accent of $shade');
      }
    });
  }

  test('light mode keeps declared colours for drawings; dark lightens them',
      () {
    expect(BrandColors.light.art(Pillars.blue), Pillars.blue);
    expect(BrandColors.dark.art(Pillars.blue), BrandColors.dark.blue);
  });

  test('tints are stronger on navy, and black tints follow the ink', () {
    expect(BrandColors.light.tint(Pillars.blue, 0.1).a, closeTo(0.1, 0.01));
    expect(BrandColors.dark.tint(Pillars.blue, 0.1).a, closeTo(0.18, 0.01));
    expect(
      BrandColors.dark.tint(Pillars.black, 0.1).withValues(alpha: 1),
      BrandColors.dark.ink,
    );
  });

  testWidgets('context.brand follows the theme, with or without the '
      'extension', (tester) async {
    late BrandColors seen;
    Widget probe() => Builder(builder: (context) {
          seen = context.brand;
          return const SizedBox();
        });

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: probe(),
    ));
    expect(seen.isDark, isTrue);
    expect(seen.background, BrandColors.dark.background);

    // A plain theme, as in some older tests: the light set, once the
    // theme has finished animating across.
    await tester.pumpWidget(MaterialApp(home: probe()));
    await tester.pumpAndSettle();
    expect(seen.background, BrandColors.light.background);
  });

  test('the appearance choice is kept between launches', () async {
    SharedPreferences.setMockInitialValues({});
    final setting = AppearanceSetting.instance;
    await setting.load();
    expect(setting.value, ThemeMode.system);

    await setting.choose(ThemeMode.dark);
    setting.value = ThemeMode.system;
    await setting.load();
    expect(setting.value, ThemeMode.dark);

    await setting.choose(ThemeMode.system);
  });
}
