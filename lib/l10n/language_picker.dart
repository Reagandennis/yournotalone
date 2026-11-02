import 'package:flutter/material.dart';

import '../brand.dart';
import 'l10n.dart';

/// What the Language row in Settings shows: the picked language's own name,
/// or "System default".
String languageSummary(BuildContext context, String? tag) =>
    LocaleSetting.instance.language?.name ?? context.l10n.languageSystemDefault;

/// System default, then every language this build offers, each named in
/// itself. The app switches as soon as one is picked, so the sheet stays
/// open long enough to see it.
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => ValueListenableBuilder<String?>(
      valueListenable: LocaleSetting.instance,
      builder: (sheetContext, _, _) {
        final c = sheetContext.brand;
        final l10n = sheetContext.l10n;
        final current = LocaleSetting.instance.language?.tag;
        Widget option({
          required String? tag,
          required String title,
          String? subtitle,
          Locale? locale,
        }) => ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            title,
            // Its own locale, so 简体中文 draws with Chinese glyphs
            // whatever the app is showing.
            locale: locale,
            style: TextStyle(fontSize: 14.5, color: c.ink),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
          trailing: tag == current
              ? Icon(Icons.check_rounded, color: c.blue)
              : null,
          selected: tag == current,
          onTap: () => LocaleSetting.instance.choose(tag),
        );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Text(
                    l10n.languageTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                ),
                option(
                  tag: null,
                  title: l10n.languageSystemDefault,
                  subtitle: l10n.languageSystemDefaultHint,
                ),
                for (final language in enabledLanguages)
                  option(
                    tag: language.tag,
                    title: language.name,
                    locale: language.locale,
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
