import 'package:flutter/material.dart';

import '../brand.dart';
import '../therapy/therapy_screen.dart';
import 'cbt_art.dart';
import 'cbt_catalog.dart';
import 'cbt_content.dart';
import 'cbt_lesson_screen.dart';
import 'cbt_ui.dart';

/// The CBT toolkit: the exercises therapists teach most, short reads on
/// the ideas behind them, and the best free material elsewhere. Every tool
/// works on its own; none of them needs an account beyond what the app
/// already has, and nothing is saved unless the person chooses to.
class CbtScreen extends StatelessWidget {
  const CbtScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const CbtScreen());

  void _push(BuildContext context, WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute(builder: builder));

  @override
  Widget build(BuildContext context) {
    return CbtScaffold(
      title: 'CBT toolkit',
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      children: [
        const Text(
          'Skills you can use today',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Cognitive behavioural therapy is the best-studied talking therapy '
          'for anxiety and depression, and much of it is learnable. These '
          'are the tools therapists hand out first — for the minutes between '
          'sessions, or before you\'ve had one.',
          style: TextStyle(fontSize: 13.5, color: Brand.textMuted, height: 1.55),
        ),
        const SizedBox(height: 24),
        const CbtSection(title: 'Tools'),
        for (final tool in cbtTools)
          CbtCard(
            title: tool.title,
            blurb: tool.blurb,
            meta: '${tool.minutes} min',
            art: tool.art,
            onTap: () => _push(context, tool.open),
          ),
        const SizedBox(height: 14),
        const CbtSection(title: 'Learn the ideas'),
        for (final lesson in cbtLessons)
          CbtCard(
            title: lesson.title,
            blurb: lesson.blurb,
            meta: '${lesson.minutes} min read',
            art: lesson.art,
            onTap: () => _push(context, (_) => CbtLessonScreen(lesson: lesson)),
          ),
        const SizedBox(height: 14),
        const CbtSection(
          title: 'Free resources',
          subtitle: 'Reputable, clinician-written material from outside the '
              'app. Links open in your browser.',
        ),
        for (final r in cbtResources)
          CbtCard(
            title: r.title,
            blurb: r.blurb,
            meta: r.by,
            art: CbtArtKind.resources,
            onTap: () => cbtOpenLink(context, r.url),
          ),
        const SizedBox(height: 14),
        Material(
          color: const Color(0x0F3764CD),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(TherapyScreen.route()),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.favorite_rounded, color: Brand.red),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Want to do this with someone?',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Brand.ink,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'A licensed therapist can take you through these '
                          'properly. Book a private video session.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Brand.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Brand.textMuted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Self-help is not a substitute for care in a crisis. If you\'re in '
          'immediate danger, use Get help now on the Home screen.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Brand.textMuted, height: 1.5),
        ),
      ],
    );
  }
}
