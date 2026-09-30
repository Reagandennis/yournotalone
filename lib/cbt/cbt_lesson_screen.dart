import 'package:flutter/material.dart';

import '../brand.dart';
import 'cbt_art.dart';
import 'cbt_content.dart';
import 'cbt_ui.dart';

/// One short read from the toolkit, laid out for reading on a phone.
class CbtLessonScreen extends StatelessWidget {
  const CbtLessonScreen({super.key, required this.lesson});

  final CbtLesson lesson;

  @override
  Widget build(BuildContext context) {
    return CbtScaffold(
      title: 'Learn',
      children: [
        Center(child: CbtArt(kind: lesson.art, size: 140)),
        const SizedBox(height: 18),
        Text(
          lesson.title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${lesson.minutes} min read',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: cbtAccent,
          ),
        ),
        const SizedBox(height: 18),
        for (final p in lesson.paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              p,
              style: const TextStyle(fontSize: 15, color: Brand.ink, height: 1.65),
            ),
          ),
      ],
    );
  }
}
