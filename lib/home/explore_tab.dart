import 'package:flutter/material.dart';

import '../brand.dart';
import '../journal/journal_editor_screen.dart';
import '../journal/journal_screen.dart';
import '../meditation/meditations_screen.dart';
import '../recovery/recovery_screen.dart';
import '../sounds/sounds_screen.dart';
import '../therapy/therapy_screen.dart';
import 'home_ui.dart';

enum _Action {
  comingSoon,
  journal,
  freeWrite,
  gratitude,
  sounds,
  meditate,
  recovery,
}

class _ExploreItem {
  const _ExploreItem(this.title, this.sub,
      {this.premium = true, this.action = _Action.comingSoon});

  final String title;
  final String sub;
  final bool premium;
  final _Action action;
}

class _ExploreSection {
  const _ExploreSection(this.title, this.icon, this.accent, this.items);

  final String title;
  final IconData icon;
  final Color accent;
  final List<_ExploreItem> items;
}

const _sections = [
  _ExploreSection(
    'Meditations & breathing',
    Icons.self_improvement_rounded,
    Brand.blue,
    [
      _ExploreItem('Box breathing', 'Free taste',
          premium: false, action: _Action.meditate),
      _ExploreItem('Morning grounding', '5 min',
          premium: false, action: _Action.meditate),
      _ExploreItem('Anxiety relief', '8 min', action: _Action.meditate),
      _ExploreItem('Body scan', '12 min', action: _Action.meditate),
      _ExploreItem('Sleep wind-down', '10 min', action: _Action.meditate),
      _ExploreItem('Loving kindness', '6 min', action: _Action.meditate),
    ],
  ),
  _ExploreSection(
    'Wellbeing sounds',
    Icons.graphic_eq_rounded,
    Brand.yellow,
    [
      _ExploreItem('Deep focus', 'Focus',
          premium: false, action: _Action.sounds),
      _ExploreItem('Rainfall', 'Sleep', action: _Action.sounds),
      _ExploreItem('Ocean waves', 'Calm', action: _Action.sounds),
      _ExploreItem('White noise', 'Focus', action: _Action.sounds),
      _ExploreItem('Crickets at night', 'Sleep', action: _Action.sounds),
    ],
  ),
  _ExploreSection(
    'Journal & mood',
    Icons.edit_note_rounded,
    Brand.red,
    [
      _ExploreItem('My journal', 'All entries',
          premium: false, action: _Action.journal),
      _ExploreItem('Free write', 'New entry',
          premium: false, action: _Action.freeWrite),
      _ExploreItem('Gratitude prompt', '3 min',
          premium: false, action: _Action.gratitude),
      _ExploreItem('Mood history', 'Insights'),
    ],
  ),
  _ExploreSection(
    'Recovery tools',
    Icons.healing_rounded,
    Brand.ink,
    [
      _ExploreItem('Urge surfing guide', '8 min',
          premium: false, action: _Action.recovery),
      _ExploreItem('Daily pledge', '1 min', action: _Action.recovery),
      _ExploreItem('Trigger tracker', 'Log & learn',
          action: _Action.recovery),
      _ExploreItem('Milestones', 'Celebrate wins', action: _Action.recovery),
    ],
  ),
];

/// Explore tab: the full catalogue of everything the app offers.
class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  Widget _itemCard(BuildContext context, _ExploreSection section,
      _ExploreItem item) {
    return SizedBox(
      width: 150,
      child: Material(
        color: section.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => switch (item.action) {
            _Action.journal => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JournalScreen()),
              ),
            _Action.freeWrite => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const JournalEditorScreen()),
              ),
            _Action.gratitude => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const JournalEditorScreen(
                    initialTitle: 'Gratitude',
                    initialContent: 'Today, I\'m grateful for ',
                  ),
                ),
              ),
            _Action.sounds => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SoundsScreen()),
              ),
            _Action.meditate => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MeditationsScreen()),
              ),
            _Action.recovery => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecoveryScreen()),
              ),
            _Action.comingSoon => showComingSoon(context, item.title),
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(section.icon, size: 18, color: section.accent),
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Brand.textMuted,
                  ),
                ),
                if (item.premium) ...[
                  const SizedBox(height: 6),
                  const PremiumChip(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 0, 28),
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Brand.ink,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
              PillarStripe(),
              SizedBox(height: 16),
              Text(
                'Everything in one place — pick whatever today calls for.',
                style: TextStyle(
                  fontSize: 14,
                  color: Brand.textMuted,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final section in _sections) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(right: 28),
            child: SectionHeader(title: section.title),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 165,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 28),
              itemCount: section.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  _itemCard(context, section, section.items[i]),
            ),
          ),
        ],
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.only(right: 28),
          child: Material(
            color: const Color(0x0F3764CD),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TherapyScreen()),
              ),
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
        ),
      ],
    );
  }
}
