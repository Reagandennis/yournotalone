import 'package:flutter/material.dart';

import '../billing/pricing_copy.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
import 'toolkit_art.dart';
import 'toolkit_content.dart';
import 'toolkit_lesson_screen.dart';
import 'toolkit_ui.dart';

/// The front page of a toolkit: what it's for, the tools, the short
/// reads, the free resources elsewhere, and a closing nudge. CBT, sleep
/// and stress all share this so they read as one family.
class ToolkitHub extends StatelessWidget {
  const ToolkitHub({
    super.key,
    required this.title,
    required this.accent,
    required this.headline,
    required this.intro,
    required this.tools,
    required this.lessons,
    required this.resources,
    required this.resourceArt,
    required this.source,
    this.toolsTitle,
    this.lessonsTitle,
    this.resourcesIntro,
    this.footer,
    this.footnote,
  });

  final String title;
  final Color accent;
  final String headline;
  final String intro;
  final List<ToolkitTool> tools;
  final List<ToolkitLesson> lessons;
  final List<ToolkitResource> resources;
  final ToolkitArtKind resourceArt;

  /// Names the programme in upgrade-sheet analytics ("cbt", "sleep").
  final String source;

  /// "Tools", "Learn the ideas" and the resources blurb unless given.
  final String? toolsTitle;
  final String? lessonsTitle;
  final String? resourcesIntro;

  /// Something to do next, under the resources — a banner, usually.
  final Widget? footer;

  /// Small print at the very end.
  final String? footnote;

  /// False, after showing the upgrade sheet, when [item] needs Premium
  /// and the person doesn't have it.
  bool _allow(
    BuildContext context, {
    required bool premium,
    required String item,
  }) {
    if (!premium || isPremiumUser()) return true;
    final l10n = context.l10n;
    showUpgradeSheet(
      context,
      item: item,
      source: 'toolkit:$source',
      title: l10n.toolkitPremiumTitle,
      message: l10n.toolkitPremiumMessage(introOffer),
    );
    return false;
  }

  void _open(BuildContext context, ToolkitTool tool) {
    if (!_allow(context, premium: tool.premium, item: tool.title)) return;
    if (tool.guard != null && !tool.guard!(context)) return;
    Navigator.of(context).push(MaterialPageRoute(builder: tool.open));
  }

  void _read(BuildContext context, ToolkitLesson lesson) {
    if (!_allow(context, premium: lesson.premium, item: lesson.title)) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ToolkitLessonScreen(lesson: lesson, accent: accent),
      ),
    );
  }

  /// "1 free · 6 Premium", the way Explore counts the other pillars. In
  /// the app's current language unless [l10n] is given.
  static String countLine(
    Iterable<bool> premiumFlags, [
    AppLocalizations? l10n,
  ]) {
    final locked = premiumFlags.where((p) => p).length;
    final free = premiumFlags.length - locked;
    return (l10n ?? currentL10n()).toolkitCountLine(free, locked);
  }

  @override
  Widget build(BuildContext context) =>
      PremiumBuilder(builder: (context, premium) => _page(context, premium));

  Widget _page(BuildContext context, bool premium) {
    final c = context.brand;
    final l10n = context.l10n;
    return ToolkitScaffold(
      accent: accent,
      title: title,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        Text(
          headline,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: c.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          intro,
          style: TextStyle(
            fontSize: 13.5,
            color: c.textMuted,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        ToolkitSection(
          title: toolsTitle ?? l10n.toolkitToolsTitle,
          subtitle: countLine(tools.map((t) => t.premium), l10n),
        ),
        for (final tool in tools)
          ToolkitCard(
            title: tool.title,
            blurb: tool.blurb,
            meta: tool.meta ?? l10n.toolkitMinutes(tool.minutes),
            art: tool.art,
            locked: tool.premium && !premium,
            onTap: () => _open(context, tool),
          ),
        if (lessons.isNotEmpty) ...[
          const SizedBox(height: 14),
          ToolkitSection(
            title: lessonsTitle ?? l10n.toolkitLessonsTitle,
            subtitle: countLine(lessons.map((l) => l.premium), l10n),
          ),
          for (final lesson in lessons)
            ToolkitCard(
              title: lesson.title,
              blurb: lesson.blurb,
              meta: l10n.toolkitMinutesRead(lesson.minutes),
              art: lesson.art,
              locked: lesson.premium && !premium,
              onTap: () => _read(context, lesson),
            ),
        ],
        if (resources.isNotEmpty) ...[
          const SizedBox(height: 14),
          ToolkitSection(
            title: l10n.toolkitFreeResources,
            subtitle: resourcesIntro ?? l10n.toolkitResourcesIntro,
          ),
          for (final r in resources)
            ToolkitCard(
              title: r.title,
              blurb: r.blurb,
              meta: r.by,
              art: resourceArt,
              onTap: () => toolkitOpenLink(context, r.url),
            ),
        ],
        if (footer != null) ...[const SizedBox(height: 14), footer!],
        if (footnote != null) ...[
          const SizedBox(height: 18),
          Text(
            footnote!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: c.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// A closing banner: an icon, a line, and somewhere to go.
class ToolkitBanner extends StatelessWidget {
  const ToolkitBanner({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
    required this.onTap,
    this.tint,
  });

  final IconData icon;

  /// Drawn as given: pass a theme colour, e.g. `context.brand.red`.
  final Color iconColor;
  final String title;
  final String detail;
  final VoidCallback onTap;

  /// The banner's wash, e.g. `context.brand.tint(...)`; a soft blue if
  /// null.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Material(
      color: tint ?? c.tint(Pillars.blue, 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
