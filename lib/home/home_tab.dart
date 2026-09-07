import 'package:flutter/material.dart';

import '../brand.dart';
import '../journal/journal_screen.dart';
import '../meditation/meditations_screen.dart';
import '../recovery/recovery_screen.dart';
import '../sounds/sounds_screen.dart';
import '../therapy/therapy_screen.dart';
import 'home_ui.dart';
import 'mood_repository.dart';
import 'mood_scale.dart';

enum _QuickAction { comingSoon, journal, sounds, meditate, recovery }

class _QuickItem {
  const _QuickItem(this.icon, this.accent, this.title, this.sub,
      {this.action = _QuickAction.comingSoon});

  final IconData icon;
  final Color accent;
  final String title;
  final String sub;
  final _QuickAction action;
}

const _quickItems = [
  _QuickItem(
    Icons.self_improvement_rounded,
    Brand.blue,
    'Meditate',
    'Breathe & settle',
    action: _QuickAction.meditate,
  ),
  _QuickItem(
    Icons.edit_note_rounded,
    Brand.red,
    'Journal',
    'Write it out',
    action: _QuickAction.journal,
  ),
  _QuickItem(
    Icons.graphic_eq_rounded,
    Brand.yellow,
    'Sounds',
    'Focus · sleep · calm',
    action: _QuickAction.sounds,
  ),
  _QuickItem(
    Icons.healing_rounded,
    Brand.ink,
    'Recovery',
    'One day at a time',
    action: _QuickAction.recovery,
  ),
];

/// Home tab: greeting, a one-tap mood check-in, quick access to the most
/// used tools, and the therapy banner.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _moodRepo = MoodRepository();
  int? _mood;

  @override
  void initState() {
    super.initState();
    // Re-light today's mood if one was already saved.
    _moodRepo.fetchTodayMoodIndex().then((index) {
      if (mounted && index != null) setState(() => _mood = index);
    }).catchError((_) {});
  }

  Future<void> _selectMood(int index) async {
    final firstTime = _mood == null;
    setState(() => _mood = index);
    try {
      await _moodRepo.saveMood(index);
      if (firstTime && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for checking in.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Couldn\'t save your mood — check your connection.'),
          ),
        );
      }
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  Widget _moodCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        border: Border.all(color: Brand.border, width: 1.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How are you feeling today?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (i, mood) in moodLevels.indexed)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectMood(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        AnimatedScale(
                          scale: _mood == i ? 1.12 : 1.0,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _mood == i
                                  ? mood.color.withValues(alpha: 0.14)
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              mood.icon,
                              size: 30,
                              color: _mood == i ? mood.color : moodIdle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mood.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _mood == i
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: _mood == i ? mood.color : Brand.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickCard(_QuickItem item) {
    return Material(
      color: item.accent.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => switch (item.action) {
          _QuickAction.journal => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const JournalScreen()),
            ),
          _QuickAction.sounds => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SoundsScreen()),
            ),
          _QuickAction.meditate => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MeditationsScreen()),
            ),
          _QuickAction.recovery => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RecoveryScreen()),
            ),
          _QuickAction.comingSoon => showComingSoon(context, item.title),
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 20, color: item.accent),
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Brand.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Brand.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Brand.textMuted,
                    ),
                  ),
                  Text(
                    firstNameOf(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Brand.ink,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Image.asset('assets/brand/pillars.png', height: 44),
          ],
        ),
        const SizedBox(height: 12),
        const PillarStripe(),
        const SizedBox(height: 24),
        _moodCard(),
        const SizedBox(height: 28),
        const SectionHeader(title: 'Quick access'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [for (final item in _quickItems) _quickCard(item)],
        ),
        const SizedBox(height: 24),
        Material(
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
                      Icons.favorite_rounded,
                      size: 22,
                      color: Brand.red,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Talk to a real therapist',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Brand.ink,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Your first session is free.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Brand.textMuted,
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
