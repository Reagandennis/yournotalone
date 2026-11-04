import 'dart:async';

import 'package:flutter/material.dart';

import '../billing/nudges.dart';
import '../billing/pricing_copy.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../journal/new_entry.dart';
import '../l10n/l10n.dart';
import 'feeling_store.dart';
import 'practice_repository.dart';

/// What a finished session ends with.
///
/// Sessions used to end on a single "Done" button and evaporate: nothing
/// recorded, nothing asked, nowhere to go. This closes the loop — it says
/// the session was kept, asks how the person feels *now* compared with
/// when they started (the one moment that answer is most informative),
/// and offers to write about it.
///
/// It used to ask with the five mood faces and save the answer as the
/// day's mood, which overwrote the morning's check-in with a post-session
/// mood. Better / same / worse is the question that's actually being
/// answered, and it's kept separately ([FeelingStore]).
class SessionCloseOut extends StatefulWidget {
  const SessionCloseOut({
    super.key,
    required this.title,
    required this.accent,
    required this.kind,
    this.slug,
    this.feelings,
  });

  /// The session just finished, as shown — seeds the journal entry.
  final String title;

  /// What the feeling is kept against ([practiceSlug] of the item's id);
  /// [title] when not given.
  final String? slug;
  final Color accent;
  final PracticeKind kind;

  /// Injectable for tests.
  final FeelingStore? feelings;

  @override
  State<SessionCloseOut> createState() => _SessionCloseOutState();
}

class _SessionCloseOutState extends State<SessionCloseOut> {
  Feeling? _picked;

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
      final l10n = context.l10n;
      showUpgradeSheet(
        context,
        source: 'nudge:practice2',
        title: l10n.practiceFreeSessionsDoneTitle,
        message: l10n.practiceFreeSessionsDoneMessage(introOffer),
      );
    } catch (e) {
      debugPrint('Practice nudge skipped: $e');
    }
  }

  Future<void> _pick(Feeling feeling) async {
    if (_picked != null) return;
    setState(() => _picked = feeling);
    // Never throws; the session still counted either way.
    await (widget.feelings ?? FeelingStore.instance).record(
      kind: widget.kind,
      slug: widget.slug ?? widget.title,
      feeling: feeling,
    );
  }

  Widget _choice(Feeling feeling, IconData icon) {
    final c = context.brand;
    final picked = _picked == feeling;
    return Expanded(
      child: AnimatedOpacity(
        opacity: _picked != null && !picked ? 0.4 : 1,
        duration: const Duration(milliseconds: 220),
        child: Material(
          color: picked ? c.tint(widget.accent, 0.16) : c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: picked ? c.accent(widget.accent) : c.border,
              width: 1.2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _pick(feeling),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                children: [
                  Icon(icon, size: 22, color: c.accent(widget.accent)),
                  const SizedBox(height: 4),
                  Text(
                    feeling.label(context.l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
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

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _picked == null ? l10n.closeOutHowDoYouFeel : l10n.closeOutNoted,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.closeOutCompared,
          style: TextStyle(fontSize: 12.5, color: c.textMuted),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _choice(Feeling.worse, Icons.south_rounded),
            const SizedBox(width: 8),
            _choice(Feeling.same, Icons.east_rounded),
            const SizedBox(width: 8),
            _choice(Feeling.better, Icons.north_rounded),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.commonDone),
        ),
        const SizedBox(height: 2),
        TextButton(
          onPressed: () => openNewJournalEntry(
            context,
            title: widget.title,
            content: l10n.closeOutJournalSeed(l10n.midSentence(widget.title)),
          ),
          child: Text(l10n.closeOutWriteAboutIt),
        ),
      ],
    );
  }
}
