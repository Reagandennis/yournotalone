import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yournotalone/brand.dart';
import 'package:yournotalone/l10n/l10n.dart';
import 'package:yournotalone/support/crisis_resources.dart';
import 'package:yournotalone/support/crisis_screen.dart';
import 'package:yournotalone/support/helplines.dart';

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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    CrisisCountrySetting.instance.value = null;
    debugDraftsOverride = null;
  });

  group('the country list', () {
    test('covers the countries the app is offered in', () {
      final codes = {for (final r in countryHelplines) r.code};
      expect(codes, hasLength(countryHelplines.length), reason: 'duplicates');
      expect(
        codes,
        containsAll([
          'KE', 'GR', 'GB', 'US', 'FR', 'DE', 'ES', 'BE', 'CH', 'CA', //
          'MX', 'AR', 'CO', 'SG', 'MY', 'TW', 'HK', 'AU', 'IE',
        ]),
      );
    });

    test('every entry is unchecked, sourced and dialable', () {
      for (final region in countryHelplines) {
        final r = region.code;
        expect(r, matches(RegExp(r'^[A-Z]{2}$')));
        // Nothing ships as checked until a person has checked it.
        expect(region.verified, isFalse, reason: r);
        expect(region.emergency, matches(RegExp(r'^\d{3}$')), reason: r);
        expect(region.emergencySource, startsWith('https://'), reason: r);
        for (final line in region.lines) {
          expect(line.source, startsWith('https://'), reason: line.name);
          expect(
            line.phone != null || line.sms != null || line.url != null,
            isTrue,
            reason: '$r · ${line.name} has no way to reach it',
          );
          if (line.phone != null) {
            expect(dialable(line.phone!), matches(RegExp(r'^\+?\d{3,}$')));
          }
        }
      }
    });

    test('the national numbers are the ones published', () {
      // Spot checks of the best-known lines, so a typo can't slip in.
      String? phone(String code, String name) => countryHelplines
          .firstWhere((r) => r.code == code)
          .lines
          .firstWhere((l) => l.name.contains(name))
          .phone;
      expect(phone('US', '988'), '988');
      expect(phone('GB', 'Samaritans'), '116 123');
      expect(phone('IE', 'Samaritans'), '116 123');
      expect(phone('FR', '3114'), '3114');
      expect(phone('DE', 'TelefonSeelsorge'), '0800 111 0 111');
      expect(phone('ES', '024'), '024');
      expect(phone('GR', '1018'), '1018');
      expect(phone('CA', '9-8-8'), '988');
      expect(phone('AU', 'Lifeline'), '13 11 14');
    });
  });

  group('picking the region', () {
    test('release builds show only checked entries, else the older list', () {
      // Kenya was in the list before; its unchecked new entry stays hidden.
      final kenya = crisisRegionFor('KE', drafts: false);
      expect(kenya, same(crisisRegions.firstWhere((r) => r.code == 'KE')));
      expect(kenya.verified, isTrue);
      // France had nothing: the international list, never unchecked lines.
      expect(crisisRegionFor('FR', drafts: false), same(internationalRegion));
      for (final region in availableCrisisRegions(drafts: false)) {
        expect(region.verified, isTrue, reason: region.code);
      }
    });

    test('with drafts on, testers see the new entries', () {
      final france = crisisRegionFor('FR', drafts: true);
      expect(france.code, 'FR');
      expect(france.verified, isFalse);
      expect(crisisRegionFor('KE', drafts: true).verified, isFalse);
      final all = availableCrisisRegions(drafts: true);
      expect(all.last, same(internationalRegion));
      expect(all.length, countryHelplines.length + 1);
    });

    test('an unknown country gets the international list', () {
      expect(crisisRegionFor('ZZ', drafts: true), same(internationalRegion));
      expect(crisisRegionFor(null, drafts: true), same(internationalRegion));
    });

    test('follows the first of the phone\'s regions it has', () {
      const phone = [Locale('nl'), Locale('nl', 'NL'), Locale('fr', 'BE')];
      expect(crisisCountry(phone, true), 'BE');
      // Without drafts there's nothing for Belgium yet.
      expect(crisisCountry(phone, false), isNull);
      expect(crisisCountry(const [Locale('en', 'GB')], false), 'GB');
      expect(crisisCountry(const [Locale('de')], true), isNull);
    });
  });

  group('the chosen country', () {
    test('wins over the phone and is kept', () async {
      await CrisisCountrySetting.instance.choose('DE');
      expect(crisisCountry(const [Locale('en', 'US')], true), 'DE');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('crisis.country'), 'DE');

      CrisisCountrySetting.instance.value = null;
      await CrisisCountrySetting.instance.load();
      expect(CrisisCountrySetting.instance.value, 'DE');

      await CrisisCountrySetting.instance.choose(null);
      expect(prefs.getString('crisis.country'), isNull);
      expect(crisisCountry(const [Locale('en', 'US')], true), 'US');
    });

    testWidgets('is picked on the crisis screen and marked unchecked', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 2400);
      addTearDown(tester.view.reset);
      debugDraftsOverride = true;

      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const CrisisScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change country'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Australia'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Australia'));
      await tester.pumpAndSettle();

      expect(find.text('Lifeline'), findsOneWidget);
      expect(find.text('Call 000'), findsOneWidget);
      expect(find.textContaining('haven\'t been checked'), findsOneWidget);
      expect(CrisisCountrySetting.instance.value, 'AU');

      // Back to the phone's region (en-US in tests).
      await tester.tap(find.text('Change country'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use my phone\'s country'));
      await tester.pumpAndSettle();
      expect(CrisisCountrySetting.instance.value, isNull);
      expect(find.text('Call 911'), findsOneWidget);
    });
  });
}
