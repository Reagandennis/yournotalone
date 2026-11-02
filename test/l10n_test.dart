import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yournotalone/l10n/l10n.dart';

Map<String, dynamic> _readArb(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

/// The message keys of an ARB file: everything but `@@locale` and the
/// `@key` metadata.
Set<String> _messageKeys(Map<String, dynamic> arb) => {
  for (final key in arb.keys)
    if (!key.startsWith('@')) key,
};

final _selector = RegExp(r'^(=\d+|zero|one|two|few|many|other|[A-Za-z_]\w*)$');
final _argument = RegExp(r'^\{\s*([A-Za-z_]\w*)\s*([,}])');

/// The ICU arguments a message uses — `{name}`, `{count, plural, …}` —
/// without the text of plural and select branches (`other{days}`), which
/// is translated and so differs between languages.
Set<String> _placeholders(String message) {
  final found = <String>{};
  // What each open brace is: an argument, or a branch of one.
  final stack = <bool>[];
  for (var i = 0; i < message.length; i++) {
    final char = message[i];
    if (char == '{') {
      final insideArgument = stack.isNotEmpty && stack.last;
      final before = message.substring(0, i).trimRight();
      final word = before.split(RegExp(r'[\s,{}]')).last;
      final isBranch = insideArgument && _selector.hasMatch(word);
      if (!isBranch) {
        final match = _argument.firstMatch(message.substring(i));
        if (match != null) {
          found.add(match.group(1)!);
          if (match.group(2) == '}') {
            i += match.group(0)!.length - 1;
            continue;
          }
        }
      }
      stack.add(!isBranch);
    } else if (char == '}' && stack.isNotEmpty) {
      stack.removeLast();
    }
  }
  return found;
}

void main() {
  group('ARB files', () {
    final dir = Directory('lib/l10n');
    final english = _readArb(File('lib/l10n/app_en.arb'));
    final englishKeys = _messageKeys(english);
    final translations = [
      for (final file in dir.listSync().whereType<File>())
        if (file.path.endsWith('.arb') && !file.path.endsWith('app_en.arb'))
          file,
    ];

    test('every English string has a description for translators', () {
      final missing = [
        for (final key in englishKeys)
          if ((english['@$key'] as Map<String, dynamic>?)?['description']
              case final String d when d.trim().isNotEmpty)
            null
          else
            key,
      ].whereType<String>().toList();
      expect(missing, isEmpty);
    });

    test('English declares exactly the placeholders it uses', () {
      for (final key in englishKeys) {
        final declared =
            ((english['@$key'] as Map<String, dynamic>?)?['placeholders']
                    as Map<String, dynamic>?)
                ?.keys
                .toSet() ??
            const <String>{};
        expect(_placeholders(english[key] as String), declared, reason: key);
      }
    });

    for (final file in translations) {
      final name = file.uri.pathSegments.last;
      final arb = _readArb(file);
      // A script variant (app_zh_Hans.arb) only overrides its base
      // language's file, so it may hold a subset.
      final isScriptVariant = RegExp(
        r'app_[a-z]+_[A-Z][a-z]{3}\.arb$',
      ).hasMatch(file.path);

      test('$name has the keys of app_en.arb', () {
        final keys = _messageKeys(arb);
        expect(
          keys.difference(englishKeys),
          isEmpty,
          reason: 'keys not in app_en.arb',
        );
        if (!isScriptVariant) {
          expect(
            englishKeys.difference(keys),
            isEmpty,
            reason: 'keys missing from $name',
          );
        }
      });

      test('$name uses the same placeholders as English', () {
        for (final key in _messageKeys(arb)) {
          final english_ = english[key];
          if (english_ is! String) continue;
          expect(
            _placeholders(arb[key] as String),
            _placeholders(english_),
            reason: '$name: $key',
          );
        }
      });
    }

    test('the placeholder reader skips plural branches', () {
      expect(
        _placeholders('{count, plural, =1{one day} other{{count} days}}'),
        {'count'},
      );
      expect(_placeholders('Hi {name}, {n, plural, other{Tage}}'), {
        'name',
        'n',
      });
      expect(_placeholders('No placeholders here.'), isEmpty);
    });
  });

  group('which languages a build offers', () {
    tearDown(() => debugDraftsOverride = null);

    test('a release build without the flag offers only reviewed ones', () {
      debugDraftsOverride = false;
      expect(enabledLanguages.map((l) => l.tag).toSet(), reviewedLocales);
      // A French phone gets English until French is reviewed, unless
      // French is reviewed already.
      expect(
        resolveDeviceLocale(const [Locale('fr', 'FR')]).languageCode,
        reviewedLocales.contains('fr') ? 'fr' : 'en',
      );
    });

    test('drafts on offers every language with strings', () {
      debugDraftsOverride = true;
      final tags = enabledLanguages.map((l) => l.tag).toList();
      expect(tags.first, 'en');
      for (final language in appLanguages) {
        if (AppLocalizations.delegate.isSupported(language.locale)) {
          expect(tags, contains(language.tag));
        }
      }
    });

    test('the phone\'s first offered language wins', () {
      debugDraftsOverride = true;
      Locale resolve(List<Locale> phone) => resolveDeviceLocale(phone);
      expect(
        resolve(const [Locale('sw'), Locale('en', 'GB')]),
        const Locale('en'),
      );
      expect(resolve(const []), const Locale('en'));
      if (AppLocalizations.delegate.isSupported(const Locale('de'))) {
        expect(
          resolve(const [Locale('de', 'AT'), Locale('en')]),
          const Locale('de'),
        );
      }
      if (AppLocalizations.delegate.isSupported(const Locale('zh'))) {
        const hans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
        expect(resolve(const [Locale('zh', 'CN')]), hans);
        expect(
          resolve(const [
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
          ]),
          hans,
        );
        // Traditional Chinese isn't offered yet: on to the next language.
        expect(
          resolve(const [Locale('zh', 'TW'), Locale('fr')]),
          const Locale('fr'),
        );
        expect(
          resolve(const [
            Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
          ]),
          const Locale('en'),
        );
      }
    });
  });

  group('LocaleSetting', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() async {
      debugDraftsOverride = null;
      await LocaleSetting.instance.choose(null);
    });

    test('saves the choice and reads it back', () async {
      debugDraftsOverride = true;
      final setting = LocaleSetting.instance;
      await setting.choose('en');
      setting.value = null;
      await setting.load();
      expect(setting.value, 'en');
      expect(setting.locale, const Locale('en'));
      await setting.choose(null);
      await setting.load();
      expect(setting.value, isNull);
      expect(setting.locale, isNull);
    });

    test('a language this build doesn\'t offer follows the phone', () async {
      debugDraftsOverride = false;
      await LocaleSetting.instance.choose('xx');
      expect(LocaleSetting.instance.locale, isNull);
    });
  });

  testWidgets('context.l10n falls back to English without the delegate', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            l10n = context.l10n;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(l10n.localeName, 'en');
    expect(l10n.languageSystemDefault, 'System default');
  });
}
