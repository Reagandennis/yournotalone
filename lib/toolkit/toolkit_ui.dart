import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../home/home_ui.dart';
import '../journal/journal_repository.dart';
import 'toolkit_art.dart';

/// The accent colour of whichever toolkit is on screen — the CBT card's
/// red, the sleep card's blue, the stress card's yellow — so the shared
/// widgets below pick it up without every screen passing it along.
class ToolkitTheme extends InheritedWidget {
  const ToolkitTheme({
    super.key,
    required this.accent,
    required this.onAccent,
    required super.child,
  });

  final Color accent;

  /// Text and icons on top of [accent]: ink on a light accent, white on a
  /// dark one.
  final Color onAccent;

  static ToolkitTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToolkitTheme>() ??
      const ToolkitTheme(
        accent: Color(0xFFC53C26),
        onAccent: Colors.white,
        child: SizedBox.shrink(),
      );

  @override
  bool updateShouldNotify(ToolkitTheme old) =>
      old.accent != accent || old.onAccent != onAccent;
}

/// Ink reads better than white on a light accent such as yellow. The
/// accent fill looks the same in both modes, so its ink does too.
Color onAccentFor(Color accent) =>
    accent.computeLuminance() > 0.4 ? BrandColors.light.ink : Colors.white;

const toolkitRadius = 18.0;

/// A toolkit page: a solid header bar in the programme's colour with the
/// title, then a scrolling body. [actions] sit in the bar.
class ToolkitScaffold extends StatelessWidget {
  const ToolkitScaffold({
    super.key,
    required this.title,
    required this.accent,
    required this.children,
    this.actions = const [],
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 32),
  });

  final String title;

  /// The programme's colour: the header bar, and through [ToolkitTheme]
  /// every accent below it.
  final Color accent;
  final List<Widget> children;
  final List<Widget> actions;

  /// Pinned under the list, for a step's main button.
  final Widget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final onAccent = onAccentFor(accent);
    return ToolkitTheme(
      accent: accent,
      onAccent: onAccent,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: accent,
          foregroundColor: onAccent,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: onAccent,
          ),
          title: Text(title),
          actions: actions,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(padding: padding, children: children),
              ),
              if (bottom != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: bottom,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list card in the reference style: title and two lines of copy on the
/// left, an illustration running off the right edge.
class ToolkitCard extends StatelessWidget {
  const ToolkitCard({
    super.key,
    required this.title,
    required this.blurb,
    required this.art,
    required this.onTap,
    this.meta,
    this.locked = false,
  });

  final String title;
  final String blurb;
  final ToolkitArtKind art;
  final VoidCallback onTap;

  /// A small line under the blurb: "4 min", "External link".
  final String? meta;

  /// Shows the Premium chip; tapping is the caller's business.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(toolkitRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 116),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            blurb,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textMuted,
                              height: 1.4,
                            ),
                          ),
                          if (meta != null || locked) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (meta != null)
                                  Flexible(
                                    child: Text(
                                      meta!,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: c.accent(
                                          ToolkitTheme.of(context).accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (locked) ...[
                                  if (meta != null) const SizedBox(width: 8),
                                  const PremiumChip(),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // The painter draws past its own square and the card
                  // clips, so the shapes run off the right edge as in the
                  // reference.
                  SizedBox(
                    width: 108,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ToolkitArt(kind: art, size: 104),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Section heading inside a toolkit, with an optional line under it.
class ToolkitSection extends StatelessWidget {
  const ToolkitSection({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: c.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Step 2 of 6" and the question for that step, at the top of a guided
/// exercise.
class ToolkitStepHeader extends StatelessWidget {
  const ToolkitStepHeader({
    super.key,
    required this.step,
    required this.of,
    required this.title,
    this.hint,
  });

  final int step;
  final int of;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final accent = c.accent(ToolkitTheme.of(context).accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= of; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == of ? 0 : 5),
                  decoration: BoxDecoration(
                    color: i <= step ? accent : c.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Step $step of $of',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: accent,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: c.ink,
            height: 1.25,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            style: TextStyle(
              fontSize: 13.5,
              color: c.textMuted,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

/// A selectable pill, the same shape as the therapy screen's.
class ToolkitPill extends StatelessWidget {
  const ToolkitPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Material(
      color: selected ? c.ink : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? c.ink : c.border,
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? c.onInk : c.ink,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? c.onInk : c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet box for a summary or a tip.
class ToolkitNote extends StatelessWidget {
  const ToolkitNote({super.key, required this.child, this.tint});

  final Widget child;

  /// The box's fill, e.g. `context.brand.tint(...)`; a plain card if null.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    // A Material rather than a Container, so list tiles and ink inside it
    // draw properly.
    return Material(
      color: tint ?? context.brand.card,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// A choice card: an icon, a title and a line, filled with ink once picked.
/// Used by every tool that asks people to pick from a list.
class ToolkitChoice extends StatelessWidget {
  const ToolkitChoice({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.detail,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? detail;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final accent = c.accent(ToolkitTheme.of(context).accent);
    final fg = selected ? c.onInk : c.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? c.ink : c.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: selected ? c.onInk : accent),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
                      if (detail != null)
                        Text(
                          detail!,
                          style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? c.onInk.withValues(alpha: 0.7)
                                : c.textMuted,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Icon(
                    trailing,
                    size: 18,
                    color: selected ? c.onInk : c.textMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Saves an exercise to the journal, respecting the free plan's cap.
/// Returns true when it was saved.
Future<bool> toolkitSaveToJournal(
  BuildContext context, {
  required String title,
  required String content,
  JournalRepository? repository,
}) async {
  final journal = repository ?? JournalRepository();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final count = await journal.countEntries();
    if (!context.mounted) return false;
    if (!journalCapAllows(context, count)) return false;
    await journal.create(title: title, content: content);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Saved to your journal.')));
    return true;
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            errorMessage(e, 'Couldn\'t save — check your connection.'),
          ),
        ),
      );
    return false;
  }
}

/// Opens an outside link in the browser, saying so if it can't.
Future<void> toolkitOpenLink(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) throw Exception('not launched');
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text('Couldn\'t open $url')));
  }
}
