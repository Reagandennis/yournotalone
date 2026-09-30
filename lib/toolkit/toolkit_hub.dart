import 'package:flutter/material.dart';

import '../brand.dart';
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
    this.toolsTitle = 'Tools',
    this.lessonsTitle = 'Learn the ideas',
    this.resourcesIntro =
        'Reputable, clinician-written material from '
        'outside the app. Links open in your browser.',
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
  final String toolsTitle;
  final String lessonsTitle;
  final String resourcesIntro;

  /// Something to do next, under the resources — a banner, usually.
  final Widget? footer;

  /// Small print at the very end.
  final String? footnote;

  void _open(BuildContext context, ToolkitTool tool) {
    if (tool.guard != null && !tool.guard!(context)) return;
    Navigator.of(context).push(MaterialPageRoute(builder: tool.open));
  }

  @override
  Widget build(BuildContext context) {
    return ToolkitScaffold(
      accent: accent,
      title: title,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        Text(
          headline,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          intro,
          style: const TextStyle(
            fontSize: 13.5,
            color: Brand.textMuted,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        ToolkitSection(title: toolsTitle),
        for (final tool in tools)
          ToolkitCard(
            title: tool.title,
            blurb: tool.blurb,
            meta: tool.meta ?? '${tool.minutes} min',
            art: tool.art,
            onTap: () => _open(context, tool),
          ),
        if (lessons.isNotEmpty) ...[
          const SizedBox(height: 14),
          ToolkitSection(title: lessonsTitle),
          for (final lesson in lessons)
            ToolkitCard(
              title: lesson.title,
              blurb: lesson.blurb,
              meta: '${lesson.minutes} min read',
              art: lesson.art,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ToolkitLessonScreen(lesson: lesson, accent: accent),
                ),
              ),
            ),
        ],
        if (resources.isNotEmpty) ...[
          const SizedBox(height: 14),
          ToolkitSection(title: 'Free resources', subtitle: resourcesIntro),
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
            style: const TextStyle(
              fontSize: 12,
              color: Brand.textMuted,
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
    this.tint = const Color(0x0F3764CD),
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tint,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Brand.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Brand.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
