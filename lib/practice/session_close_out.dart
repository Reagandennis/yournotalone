import 'dart:async';

import 'package:flutter/material.dart';

import '../billing/nudges.dart';
import '../billing/pricing_copy.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../home/mood_face.dart';
import '../home/mood_repository.dart';
import '../home/mood_scale.dart';
import '../journal/new_entry.dart';
import 'practice_repository.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(_nudgeAfterFreeSessions());
  }

  /// Someone who has just finished their second session has used up the
  /// free ones and liked them enough to come back. Once per account.
  Future<void> _nudgeAfterFreeSessions() async {
    if (isPremiumUser()) return;
    try {
      final summary = await PracticeRepository().fetchSummary();
      if (summary.sessions < 2 || !mounted) return;
      if (!await Nudges.claim('practice2') || !mounted) return;
      showUpgradeSheet(
        context,
        source: 'nudge:practice2',
        title: 'You\'ve finished your free sessions',
        message: 'Premium opens all 20 meditations and every breathing '
            'exercise, with the sounds to go with them — and $introOffer.',
      );
    } catch (e) {
      debugPrint('Practice nudge skipped: $e');
    }
  }

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
    final c = context.brand;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _picked == null ? 'How do you feel now?' : 'Noted. Thank you.',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: c.ink,
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
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedScale(
                      scale: _picked == i ? 1.14 : 1.0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: MoodFace(
                        level: mood,
                        size: 36,
                        dimmed: _picked != null && _picked != i,
                      ),
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
