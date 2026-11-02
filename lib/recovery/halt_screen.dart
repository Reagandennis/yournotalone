import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
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

  /// Which of the four this is; the HALT letter in English.
  final String letter;

  /// The words, in the language being shown.
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) question;
  final IconData icon;
  final Color accent;
  final String Function(AppLocalizations) advice;
  final String Function(AppLocalizations) action;
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
    title: (l) => l.haltHungryTitle,
    question: (l) => l.haltHungryQuestion,
    icon: Icons.restaurant_rounded,
    accent: Pillars.yellow,
    advice: (l) => l.haltHungryAdvice,
    action: (l) => l.haltHungryAction,
    open: (context) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeditationScreen(meditation: _meditation('Midday reset')),
      ),
    ),
  ),
  _Need(
    letter: 'A',
    title: (l) => l.haltAngryTitle,
    question: (l) => l.haltAngryQuestion,
    icon: Icons.local_fire_department_rounded,
    accent: Pillars.red,
    advice: (l) => l.haltAngryAdvice,
    action: (l) => l.haltAngryAction,
    open: (context) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            MeditationScreen(meditation: _meditation('Letting go of anger')),
      ),
    ),
  ),
  _Need(
    letter: 'L',
    title: (l) => l.haltLonelyTitle,
    question: (l) => l.haltLonelyQuestion,
    icon: Icons.people_alt_rounded,
    accent: Pillars.blue,
    advice: (l) => l.haltLonelyAdvice,
    action: (l) => l.haltLonelyAction,
    open: (context) => Navigator.of(context).push(TherapyScreen.route()),
  ),
  _Need(
    letter: 'T',
    title: (l) => l.haltTiredTitle,
    question: (l) => l.haltTiredQuestion,
    icon: Icons.bedtime_rounded,
    accent: Pillars.black,
    advice: (l) => l.haltTiredAdvice,
    action: (l) => l.haltTiredAction,
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

  /// The letter on a need's disc, which a language can change to fit its
  /// own words for the four.
  String _letter(AppLocalizations l10n, String letter) => switch (letter) {
        'H' => l10n.haltHungryLetter,
        'A' => l10n.haltAngryLetter,
        'L' => l10n.haltLonelyLetter,
        _ => l10n.haltTiredLetter,
      };

  Widget _option(_Need need) {
    final c = context.brand;
    final on = _picked.contains(need.letter);
    // The picked letter sits on a solid disc of the need's colour. Pillar
    // colours stay as they are under white; the black one is the ink fill,
    // which turns off-white in the dark.
    final black = need.accent == Pillars.black;
    final disc = black ? c.ink : need.accent;
    final onDisc = black ? c.onInk : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: on ? c.tint(need.accent, 0.09) : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: on ? c.accent(need.accent) : c.border,
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
                    color: on ? disc : c.tint(Pillars.black, 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _letter(context.l10n, need.letter),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: on ? onDisc : c.textMuted,
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
                        need.title(context.l10n),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        need.question(context.l10n),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textMuted,
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
                  color: on ? c.accent(need.accent) : c.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _answer(_Need need) {
    final c = context.brand;
    final accent = c.accent(need.accent);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.tint(need.accent, 0.06),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(need.icon, size: 19, color: accent),
                const SizedBox(width: 10),
                Text(
                  need.title(context.l10n),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              need.advice(context.l10n),
              style: TextStyle(
                fontSize: 13.5,
                color: c.ink,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => need.open(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent, width: 1.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(need.action(context.l10n)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
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
                Text(
                  context.l10n.haltTitle,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                Text(
                  context.l10n.haltIntro,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
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
                      color: c.tint(Pillars.black, 0.04),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      context.l10n.haltNoneOfThem,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.textMuted,
                        height: 1.5,
                      ),
                    ),
                  )
                else ...[
                  SectionHeader(title: context.l10n.haltWhatThatMeans),
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
