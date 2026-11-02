import '../l10n/l10n.dart';

/// Everything backgrounds say on screen, from the ARB files (`background*`
/// keys) in the app's current language.
abstract final class BackgroundStrings {
  static AppLocalizations get _l => currentL10n();

  static String get calmVisuals => _l.backgroundCalmVisuals;
  static String get calmVisualsHint => _l.backgroundCalmVisualsHint;
  static String get reduceMotionNote => _l.backgroundReduceMotionNote;
  static String get pickerTitle => _l.backgroundPickerTitle;
  static String get pickerTooltip => _l.backgroundPickerTooltip;
}
