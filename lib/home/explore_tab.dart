import 'package:flutter/material.dart';

import '../brand.dart';
import '../journal/journal_hub_screen.dart';
import '../journal/journal_prompts.dart';
import '../meditation/meditation_catalog.dart';
import '../meditation/meditations_screen.dart';
import '../recovery/recovery_screen.dart';
import '../sounds/sounds_catalog.dart';
import '../sounds/sounds_screen.dart';
import '../therapy/therapy_screen.dart';
import 'home_ui.dart';

/// One line of the preview shown on a category card — the same items the
/// user meets at the top of the list once the card is opened.
class _PreviewItem {
  const _PreviewItem(this.title, this.meta, this.icon, {this.premium = true});

  final String title;
  final String meta;
  final IconData icon;
  final bool premium;
}

class _ExploreCategory {
  const _ExploreCategory({
    required this.title,
    required this.blurb,
    required this.icon,
    required this.accent,
    required this.items,
    required this.open,
  });

  final String title;
  final String blurb;
  final IconData icon;
  final Color accent;

  /// Everything inside, in the order the destination screen lists it.
  final List<_PreviewItem> items;
  final WidgetBuilder open;
}

/// Built from the real catalogues so the previews can never drift from
/// what the destination screens actually offer.
final _categories = <_ExploreCategory>[
  _ExploreCategory(
    title: 'Meditations & breathing',
    blurb: 'Breathe along with the circle, or settle into a guided session.',
    icon: Icons.self_improvement_rounded,
    accent: Brand.blue,
    items: [
      for (final p in breathPatterns)
        _PreviewItem(p.title, p.rhythmLabel, Icons.air_rounded,
            premium: p.premium),
      for (final m in meditations)
        _PreviewItem(m.title, '${m.minutes} min', m.icon, premium: m.premium),
    ],
    open: (_) => const MeditationsScreen(),
  ),
  _ExploreCategory(
    title: 'Wellbeing sounds',
    blurb: 'Loops that keep running while you focus, drift off, or settle.',
    icon: Icons.graphic_eq_rounded,
    accent: Brand.yellow,
    items: [
      for (final s in soundsCatalog)
        _PreviewItem(s.title, s.category.label, s.icon, premium: s.premium),
    ],
    open: (_) => const SoundsScreen(),
  ),
  _ExploreCategory(
    title: 'Journal & mood',
    blurb: 'A blank page when you need one, a prompt when you don\'t.',
    icon: Icons.edit_note_rounded,
    accent: Brand.red,
    items: [
      const _PreviewItem('My journal', 'All entries', Icons.menu_book_rounded,
          premium: false),
      const _PreviewItem('Free write', 'New entry', Icons.edit_note_rounded,
          premium: false),
      for (final p in journalPrompts)
        _PreviewItem(p.title, 'Prompt', p.icon, premium: p.premium),
      const _PreviewItem('Mood history', 'Insights', Icons.insights_rounded),
    ],
    open: (_) => const JournalHubScreen(),
  ),
  _ExploreCategory(
    title: 'Recovery tools',
    blurb: 'One day at a time — with tools for the hard minutes.',
    icon: Icons.healing_rounded,
    accent: Brand.ink,
    items: const [
      _PreviewItem('Urge surfing', '8 min', Icons.surfing_rounded,
          premium: false),
      _PreviewItem('HALT check', 'In the moment',
          Icons.psychology_alt_rounded),
      _PreviewItem('Play the tape forward', 'In the moment',
          Icons.movie_filter_rounded),
      _PreviewItem('My commitments', 'Daily streaks', Icons.verified_rounded),
      _PreviewItem('Milestones', 'Celebrate wins', Icons.emoji_events_rounded),
      _PreviewItem('Trigger tracker', 'Log & learn', Icons.bolt_rounded),
      _PreviewItem('Trigger insights', 'Your patterns',
          Icons.query_stats_rounded),
    ],
    open: (_) => const RecoveryScreen(),
  ),
];

/// How many items each card previews before falling back to "+N more".
const _previewCount = 3;

/// Explore tab: one card per pillar, each previewing what's inside and
/// opening the full, scrollable list to pick from.
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  Widget _previewRow(_PreviewItem item, Color accent, bool premium) {
    final locked = item.premium && !premium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(item.icon, size: 14, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Brand.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The badge earns the space the detail would have taken: what
          // matters in a preview is which items are behind Premium.
          if (locked)
            const PremiumChip()
          else
            Text(
              item.meta,
              maxLines: 1,
              style: const TextStyle(fontSize: 11.5, color: Brand.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _categoryCard(BuildContext context, _ExploreCategory category) {
    final premium = isPremiumUser();
    final shown = category.items.take(_previewCount);
    final more = category.items.length - shown.length;
    final free = category.items.where((i) => !i.premium).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Brand.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: category.open),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: category.accent.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(category.icon,
                          size: 21, color: category.accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: Brand.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            premium
                                ? '${category.items.length} to pick from'
                                : '$free free · ${category.items.length - free}'
                                    ' Premium',
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Brand.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: category.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  category.blurb,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Brand.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: category.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      for (final item in shown)
                        _previewRow(item, category.accent, premium),
                      if (more > 0) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+ $more more inside',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: category.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        const Text(
          'Explore',
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
          'Everything in one place — open a card to see the full list and '
          'pick whatever today calls for.',
          style: TextStyle(
            fontSize: 14,
            color: Brand.textMuted,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        for (final category in _categories) _categoryCard(context, category),
        const SizedBox(height: 12),
        Material(
          color: const Color(0x0F3764CD),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(TherapyScreen.route()),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      size: 22,
                      color: Brand.blue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Real human therapy',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Brand.ink,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Book a private session — your first one is free.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Brand.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: Brand.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
