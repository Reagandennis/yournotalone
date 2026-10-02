import 'package:flutter/material.dart';

import '../brand.dart';
import 'toolkit_art.dart';
import 'toolkit_content.dart';
import 'toolkit_ui.dart';

/// One short read from the toolkit, laid out for reading on a phone.
class ToolkitLessonScreen extends StatelessWidget {
  const ToolkitLessonScreen({
    super.key,
    required this.lesson,
    required this.accent,
  });

  final ToolkitLesson lesson;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return ToolkitScaffold(
      accent: accent,
      title: 'Learn',
      children: [
        Center(child: ToolkitArt(kind: lesson.art, size: 140)),
        const SizedBox(height: 18),
        Text(
          lesson.title,
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: c.ink,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${lesson.minutes} min read',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: c.accent(accent),
          ),
        ),
        const SizedBox(height: 18),
        for (final p in lesson.paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              p,
              style: TextStyle(
                fontSize: 15,
                color: c.ink,
                height: 1.65,
              ),
            ),
          ),
      ],
    );
  }
}
