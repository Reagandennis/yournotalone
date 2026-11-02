// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get somethingWentWrongTitle => 'Something went wrong here.';

  @override
  String get somethingWentWrongBody =>
      'Go back and try again — nothing you saved is affected.';

  @override
  String get appearanceSystem => 'Match my phone';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystemDefault => 'System default';

  @override
  String get languageSystemDefaultHint => 'Follows your phone\'s language.';
}
