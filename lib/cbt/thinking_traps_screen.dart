import 'package:flutter/material.dart';

import '../brand.dart';
import 'cbt_content.dart';
import '../toolkit/toolkit_ui.dart';

/// The field guide to unhelpful thinking: eleven traps, each with how it
/// sounds, an example, and the question that loosens it. Tap one to open
/// it; type a thought at the top to keep it in view while you look.
class ThinkingTrapsScreen extends StatefulWidget {
  const ThinkingTrapsScreen({super.key});

  @override
  State<ThinkingTrapsScreen> createState() => _ThinkingTrapsScreenState();
}

class _ThinkingTrapsScreenState extends State<ThinkingTrapsScreen> {
  final _thought = TextEditingController();
  String? _open;

  @override
  void dispose() {
    _thought.dispose();
    super.dispose();
  }

  Widget _trapCard(ThinkingTrap trap) {
    final open = _open == trap.name;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: toolkitCardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = open ? null : trap.name),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(trap.icon, size: 19, color: cbtAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trap.name,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Brand.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '“${trap.soundsLike}”',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Brand.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Brand.textMuted,
                    ),
                  ],
                ),
                if (open) ...[
                  const SizedBox(height: 14),
                  _row('For example', trap.example),
                  const SizedBox(height: 10),
                  _row('Ask yourself', trap.ask, strong: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String text, {bool strong = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: cbtAccent,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: strong ? FontWeight.w500 : FontWeight.w400,
            color: Brand.ink,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolkitScaffold(
      accent: cbtAccent,
      title: 'Thinking traps',
      children: [
        const ToolkitSection(
          title: 'Spot the pattern',
          subtitle:
              'Anxious and low moods run on a handful of predictable '
              'distortions. Naming one takes some of its power away. Write '
              'the thought that\'s bothering you, then see which of these '
              'it\'s wearing.',
        ),
        TextField(
          controller: _thought,
          maxLines: 2,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'The thought (optional)',
            counterText: '',
          ),
        ),
        if (_thought.text.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          ToolkitNote(
            tint: const Color(0x14C53C26),
            child: Text(
              '“${_thought.text.trim()}”\n\nWhich of these does it sound like?',
              style: const TextStyle(
                fontSize: 13,
                color: Brand.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
        const SizedBox(height: 22),
        for (final trap in thinkingTraps) _trapCard(trap),
        const SizedBox(height: 8),
        const ToolkitNote(
          child: Text(
            'Found one? The thought record walks you through checking the '
            'evidence and writing something fairer.',
            style: TextStyle(fontSize: 13, color: Brand.textMuted, height: 1.5),
          ),
        ),
      ],
    );
  }
}
