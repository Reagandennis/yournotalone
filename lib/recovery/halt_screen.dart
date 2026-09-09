import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../meditation/meditation_catalog.dart';
import '../meditation/meditation_screen.dart';
import '../sounds/sounds_catalog.dart';
import '../sounds/player_screen.dart';
import '../therapy/therapy_screen.dart';

/// What a craving is often standing in for. Each one carries the thing
/// worth doing about it, and where in the app to do it.
class _Need {
  const _Need({
    required this.letter,
    required this.title,
    required this.question,
    required this.icon,
    required this.accent,
    required this.advice,
    required this.action,
    required this.open,
  });

  final String letter;
  final String title;
  final String question;
  final IconData icon;
  final Color accent;
  final String advice;
  final String action;
  final void Function(BuildContext) open;
}

// These link HALT to catalogue entries by title. `firstWhere` throws if a
// title is ever edited, which would crash the screen at the worst possible
// moment — so fall back to the first entry, and let a test catch the
// broken link instead of a user.
Meditation _meditation(String title) => meditations.firstWhere(
      (m) => m.title == title,
      orElse: () => meditations.first,
    );

Sound _sound(String title) => soundsCatalog.firstWhere(
      (s) => s.title == title,
      orElse: () => soundsCatalog.first,
    );

/// The catalogue entries HALT sends people to. Checked by a test, so
/// renaming one of them fails the build rather than the app.
const haltMeditationTitles = ['Midday reset', 'Letting go of anger'];
const haltSoundTitles = ['Pink noise'];

final _needs = <_Need>[
  _Need(
    letter: 'H',
    title: 'Hungry',
    question: 'When did you last eat something proper?',
    icon: Icons.restaurant_rounded,
    accent: Brand.yellow,
    advice: 'Low blood sugar feels a lot like craving, and it argues with '
        'you the same way. Eat something first — a real meal if you can, '
        'anything if you can\'t — then see what\'s left of the urge.',
    action: 'Steady the breath while you eat',
    open: (context) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeditationScreen(meditation: _meditation('Midday reset')),
      ),
    ),
  ),
  _Need(
    letter: 'A',
    title: 'Angry',
    question: 'Is something still sitting unsaid?',
    icon: Icons.local_fire_department_rounded,
    accent: Brand.red,
    advice: 'Anger wants somewhere to go, and the old habit is the easiest '
        'door. Give it a different one for nine minutes and see if it '
        'still wants the same thing.',
    action: 'Letting go of anger · 9 min',
    open: (context) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MeditationScreen(meditation: _meditation('Letting go of anger')),
      ),
    ),
  ),
  _Need(
    letter: 'L',
    title: 'Lonely',
    question: 'Who have you actually spoken to today?',
    icon: Icons.people_alt_rounded,
    accent: Brand.blue,
    advice: 'This is the one that most often gets answered with the habit. '
        'A real person beats anything else here — and if there isn\'t one '
        'right now, a session is a person.',
    action: 'Talk to a therapist',
    open: (context) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TherapyScreen()),
    ),
  ),
  _Need(
    letter: 'T',
    title: 'Tired',
    question: 'Have you slept properly this week?',
    icon: Icons.bedtime_rounded,
    accent: Brand.ink,
    advice: 'Tired makes every urge louder and every reason quieter. '
        'Nothing you decide right now will be as good as what you decide '
        'after some rest.',
    action: 'Wind down and sleep',
    open: (context) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(sound: _sound('Pink noise'))),
    ),
  ),
];

/// The HALT check: before acting on a craving, work out which of the four
/// it actually is. Pick any that fit and each one answers back.
class HaltScreen extends StatefulWidget {
  const HaltScreen({super.key});

  @override
  State<HaltScreen> createState() => _HaltScreenState();
}

class _HaltScreenState extends State<HaltScreen> {
  final _picked = <String>{};

  Widget _option(_Need need) {
    final on = _picked.contains(need.letter);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: on ? need.accent.withValues(alpha: 0.09) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: on ? need.accent : Brand.border,
            width: on ? 1.6 : 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() {
            if (!_picked.remove(need.letter)) _picked.add(need.letter);
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: on ? need.accent : const Color(0x0A191919),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      need.letter,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: on ? Colors.white : Brand.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        need.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        need.question,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Brand.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  on
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 22,
                  color: on ? need.accent : Brand.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _answer(_Need need) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: need.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(need.icon, size: 19, color: need.accent),
                const SizedBox(width: 10),
                Text(
                  need.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              need.advice,
              style: const TextStyle(
                fontSize: 13.5,
                color: Brand.ink,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => need.open(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: need.accent,
                  side: BorderSide(color: need.accent, width: 1.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(need.action),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picked = [for (final n in _needs) if (_picked.contains(n.letter)) n];
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
                  'HALT check',
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
                  'A craving is often something else wearing a disguise. '
                  'Before you decide anything, check the four it\'s usually '
                  'hiding behind — tick whichever are true.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Brand.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                for (final need in _needs) _option(need),
                const SizedBox(height: 14),
                if (picked.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x0A191919),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'None of them? Then it\'s the urge on its own — and '
                      'those pass on their own too. Ride it out.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Brand.textMuted,
                        height: 1.5,
                      ),
                    ),
                  )
                else ...[
                  const SectionHeader(title: 'What that means'),
                  const SizedBox(height: 12),
                  for (final need in picked) _answer(need),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
