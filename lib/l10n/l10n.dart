/// The app's languages: which ones exist, which ones a build offers, the
/// person's choice in Settings, and `context.l10n` for the strings.
///
/// The strings themselves live in the ARB files next to this one; see
/// README.md in this folder for how to add one or review a language.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// A language the app has strings for. [tag] is what Settings saves and
/// [reviewedLocales] lists; [name] is the language's name in itself, so
/// someone can find their own language whatever the app is showing.
class AppLanguage {
  const AppLanguage(this.tag, this.name, this.locale);

  final String tag;
  final String name;
  final Locale locale;
}

const appLanguages = <AppLanguage>[
  AppLanguage('en', 'English', Locale('en')),
  AppLanguage('fr', 'Français', Locale('fr')),
  AppLanguage('de', 'Deutsch', Locale('de')),
  AppLanguage('es', 'Español', Locale('es')),
  AppLanguage(
    'zh-Hans',
    '简体中文',
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ),
];

/// Languages a fluent person has read through. Mental-health and crisis
/// wording is too easy to get subtly wrong, so a release build only offers
/// these. Add a tag here once its review is done (see README.md).
const reviewedLocales = <String>{'en'};

/// `--dart-define=L10N_DRAFTS=true` turns on every drafted language in a
/// release build, for testers and reviewers.
const _draftsFlag = bool.fromEnvironment('L10N_DRAFTS');

/// Whether unreviewed languages are on: always while developing, and in a
/// release build only with the flag above.
bool get l10nDraftsEnabled =>
    debugDraftsOverride ?? (_draftsFlag || !kReleaseMode);

/// Lets tests check what a release build without the flag offers.
@visibleForTesting
bool? debugDraftsOverride;

/// The languages this build offers, English first: those with strings,
/// and of those the reviewed ones unless drafts are on.
List<AppLanguage> get enabledLanguages => [
  for (final language in appLanguages)
    if (AppLocalizations.delegate.isSupported(language.locale) &&
        (l10nDraftsEnabled || reviewedLocales.contains(language.tag)))
      language,
];

List<Locale> get enabledLocales => [
  for (final language in enabledLanguages) language.locale,
];

AppLanguage? _languageForTag(String? tag) {
  for (final language in enabledLanguages) {
    if (language.tag == tag) return language;
  }
  return null;
}

/// The language for a phone set to [preferred] (most wanted first), when
/// nothing is chosen in Settings: the first one the app has, else English.
///
/// Any Simplified-Chinese phone gets `zh-Hans`. Traditional Chinese
/// (`zh-Hant`, or Taiwan, Hong Kong and Macau) isn't offered yet, so those
/// phones move on down their list rather than get the Simplified script.
Locale resolveDeviceLocale(Iterable<Locale>? preferred) {
  for (final locale in preferred ?? const <Locale>[]) {
    final String tag;
    if (locale.languageCode == 'zh') {
      final traditional =
          locale.scriptCode == 'Hant' ||
          (locale.scriptCode == null &&
              const {'TW', 'HK', 'MO'}.contains(locale.countryCode));
      if (traditional) continue;
      tag = 'zh-Hans';
    } else {
      tag = locale.languageCode;
    }
    final language = _languageForTag(tag);
    if (language != null) return language.locale;
  }
  return appLanguages.first.locale;
}

/// The language picked in Settings, or null to follow the phone. Kept on
/// this device, like [AppearanceSetting].
class LocaleSetting extends ValueNotifier<String?> {
  LocaleSetting._() : super(null);

  static final instance = LocaleSetting._();

  static const _key = 'language';

  /// Reads the saved choice. Never fatal: without storage the app simply
  /// follows the phone.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = prefs.getString(_key);
    } catch (e) {
      debugPrint('Language setting unavailable: $e');
    }
  }

  /// Saves [tag], or null for the phone's language.
  Future<void> choose(String? tag) async {
    value = tag;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (tag == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, tag);
      }
    } catch (e) {
      debugPrint('Couldn\'t save the language setting: $e');
    }
  }

  /// The chosen language, if this build offers it. A choice saved under a
  /// build with drafts on falls back to the phone's language in one without.
  AppLanguage? get language => _languageForTag(value);

  /// The locale MaterialApp is pinned to, or null to follow the phone.
  Locale? get locale => language?.locale;
}

/// The strings for the language the app is showing, for code with no
/// [BuildContext] — a notification scheduled in the background, say. Call
/// [LocaleSetting.load] first in a fresh isolate.
AppLocalizations currentL10n() => lookupAppLocalizations(
  LocaleSetting.instance.locale ??
      resolveDeviceLocale(PlatformDispatcher.instance.locales),
);

extension MidSentence on AppLocalizations {
  /// [text] as it reads inside a sentence: lower-cased ("more for “feeling
  /// low”"), except in German, whose nouns keep their capital letter.
  String midSentence(String text) =>
      localeName == 'de' ? text : text.toLowerCase();
}

extension AppL10n on BuildContext {
  /// The app's strings in the current language. Falls back to English
  /// where there is no app-level [Localizations] — a widget test that pumps
  /// a bare MaterialApp, for one — so a screen always has its words.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? _english;
}

final _english = lookupAppLocalizations(const Locale('en'));
