import 'package:flutter/material.dart';
import '../billing/pricing_copy.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../home/mood_history_screen.dart';
import 'journal_prompts.dart';
import 'journal_repository.dart';
import 'new_entry.dart';
import 'journal_screen.dart';

/// Hub for the journal & mood section: the entry list and a blank page up
/// top, then guided prompts to pick from.
class JournalHubScreen extends StatelessWidget {
  const JournalHubScreen({super.key, this.journal});

  /// Injectable so the free-entry cap can be tested without a backend.
  final JournalRepository? journal;

  Future<void> _openEditor(
    BuildContext context, {
    String? title,
    String? content,
  }) =>
      openNewJournalEntry(
        context,
        title: title,
        content: content,
        journal: journal,
      );

  bool _guardPremium(BuildContext context, String title, String message) {
    if (isPremiumUser()) return true;
    showUpgradeSheet(context, title: title, message: message);
    return false;
  }

  bool _guardPrompt(BuildContext context, bool premium) =>
      !premium ||
      _guardPremium(
        context,
        'This prompt is part of Premium',
        'Free includes a prompt to try. Premium unlocks all '
            '${journalPrompts.length} — and $introOffer.',
      );

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String detail,
    required VoidCallback onTap,
    bool locked = false,
    bool tinted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: tinted ? accent.withValues(alpha: 0.06) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: tinted
              ? BorderSide.none
              : const BorderSide(color: Brand.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tinted
                        ? Colors.white
                        : accent.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 21, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Brand.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // The badge takes the chevron's slot, so a long prompt
                // title keeps the whole row to itself.
                if (locked)
                  const PremiumChip()
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PremiumBuilder(
        builder: (context, _) => _buildContent(context),
      );

  /// Wrapped by [PremiumBuilder] above, so this repaints the moment the
  /// entitlement changes — buying from inside the app used to leave the
  /// screen you bought from still locked.
  Widget _buildContent(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BackChip(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Journal & mood',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                const Text(
                  'Put the day into words — start from a blank page or let '
                  'a prompt do the opening line.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Brand.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Write'),
                const SizedBox(height: 12),
                _card(
                  context,
                  icon: Icons.menu_book_rounded,
                  accent: Brand.red,
                  title: 'My journal',
                  detail: 'Every entry you\'ve written, newest first.',
                  tinted: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JournalScreen()),
                  ),
                ),
                _card(
                  context,
                  icon: Icons.edit_note_rounded,
                  accent: Brand.blue,
                  title: 'Free write',
                  detail: 'A blank page, no prompt, no rules.',
                  tinted: true,
                  onTap: () => _openEditor(context),
                ),
                for (final group in promptGroups) ...[
                  const SizedBox(height: 14),
                  SectionHeader(title: group),
                  const SizedBox(height: 12),
                  for (final prompt in journalPrompts)
                    if (prompt.group == group)
                      _card(
                        context,
                        icon: prompt.icon,
                        accent: prompt.accent,
                        title: prompt.title,
                        detail: prompt.detail,
                        locked: prompt.premium && !isPremiumUser(),
                        onTap: () {
                          if (!_guardPrompt(context, prompt.premium)) return;
                          _openEditor(
                            context,
                            title: prompt.title,
                            content: prompt.seed,
                          );
                        },
                      ),
                ],
                const SizedBox(height: 14),
                const SectionHeader(title: 'Mood'),
                const SizedBox(height: 12),
                _card(
                  context,
                  icon: Icons.insights_rounded,
                  accent: Brand.yellow,
                  title: 'Mood history',
                  detail: 'Every check-in, and how the weeks actually went.',
                  locked: !isPremiumUser(),
                  onTap: () {
                    if (!_guardPremium(
                      context,
                      'Mood history is part of Premium',
                      'Checking in is always free. Premium keeps the record '
                          'and shows you the pattern — and $introOffer.',
                    )) {
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MoodHistoryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
