import 'package:flutter/material.dart';

import '../brand.dart';
import '../home/mood_repository.dart';
import '../home/mood_scale.dart';
import '../journal/new_entry.dart';

/// What a finished session ends with.
///
/// Sessions used to end on a single "Done" button and evaporate: nothing
/// recorded, nothing asked, nowhere to go. This closes the loop — it says
/// the session was kept, asks how the person feels *now* (the one moment
/// that answer is most informative), and offers to write about it.
class SessionCloseOut extends StatefulWidget {
  const SessionCloseOut({
    super.key,
    required this.title,
    required this.accent,
    this.moodRepository,
  });

  /// The session just finished — seeds the journal entry.
  final String title;
  final Color accent;
  final MoodRepository? moodRepository;

  @override
  State<SessionCloseOut> createState() => _SessionCloseOutState();
}

class _SessionCloseOutState extends State<SessionCloseOut> {
  late final _moods = widget.moodRepository ?? MoodRepository();
  int? _picked;

  Future<void> _pick(int index) async {
    setState(() => _picked = index);
    try {
      await _moods.saveMood(index);
    } catch (_) {
      // The session still counted; a missed mood isn't worth an error here.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _picked == null ? 'How do you feel now?' : 'Noted. Thank you.',
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, mood) in moodLevels.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _pick(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _picked == i
                          ? mood.color.withValues(alpha: 0.14)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      mood.icon,
                      size: 30,
                      color: _picked == i ? mood.color : moodIdle,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Done'),
        ),
        const SizedBox(height: 2),
        TextButton(
          onPressed: () => openNewJournalEntry(
            context,
            title: widget.title,
            content: 'After ${widget.title.toLowerCase()}, I noticed ',
          ),
          child: const Text('Write about it'),
        ),
      ],
    );
  }
}
