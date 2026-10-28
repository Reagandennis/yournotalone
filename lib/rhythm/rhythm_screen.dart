import 'package:flutter/material.dart';

import '../brand.dart';
import 'rhythm.dart';
import 'rhythm_card.dart';
import 'sunrise_art.dart';

/// The week's sunrise up close: the weekly goal, the last twelve weeks,
/// and what counts as showing up.
class RhythmScreen extends StatefulWidget {
  const RhythmScreen({super.key, required this.rhythm});

  final Rhythm rhythm;

  @override
  State<RhythmScreen> createState() => _RhythmScreenState();
}

class _RhythmScreenState extends State<RhythmScreen> {
  late Rhythm _rhythm = widget.rhythm;

  Future<void> _setGoal(int goal) async {
    setState(() => _rhythm = _rhythm.withGoal(goal));
    try {
      await RhythmGoal.save(goal);
    } catch (error) {
      debugPrint('Could not save the weekly goal: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final r = _rhythm;
    return Scaffold(
      appBar: AppBar(title: const Text('Your rhythm')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          SunriseArt(
            progress: r.progress,
            height: 210,
            borderRadius: BorderRadius.circular(22),
          ),
          const SizedBox(height: 20),
          Text(
            rhythmHeadline(r),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: c.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rhythmDetail(r),
            style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          RhythmWeek(rhythm: r, size: 28),
          const SizedBox(height: 28),
          _heading(context, 'Your weekly goal'),
          const SizedBox(height: 6),
          Text(
            'How many days a week feels right? The other days are rest '
            'days — they\'re part of the rhythm too.',
            style: TextStyle(fontSize: 13.5, color: c.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var g = 1; g <= 7; g++)
                ChoiceChip(
                  label: Text('$g'),
                  selected: r.goal == g,
                  onSelected: (_) => _setGoal(g),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${r.goal} ${r.goal == 1 ? 'day' : 'days'} a week',
            style: TextStyle(fontSize: 12.5, color: c.textMuted),
          ),
          const SizedBox(height: 28),
          _heading(context, 'The last twelve weeks'),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final days in r.pastWeeks)
                Expanded(
                  child: Center(
                    child: WeekSun(fill: (days / r.goal).clamp(0.0, 1.0)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat(context, '${r.weeksInRhythm}', 'week rhythm'),
              _stat(context, '${r.bestWeeks}', 'longest'),
              _stat(context, '${r.totalDays}', 'days in total'),
            ],
          ),
          const SizedBox(height: 28),
          _heading(context, 'What counts'),
          const SizedBox(height: 8),
          for (final (icon, text) in const [
            (Icons.mood_rounded, 'A mood check-in'),
            (
              Icons.self_improvement_rounded,
              'A meditation or breathing exercise',
            ),
            (Icons.graphic_eq_rounded, 'Listening to a sound'),
            (Icons.edit_note_rounded, 'A journal entry'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: c.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 14, color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'One small step is enough for the day. Nothing is lost when you '
            'take a break — every day you\'ve shown up stays counted.',
            style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _heading(BuildContext context, String text) => Text(
    text,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: context.brand.ink,
    ),
  );

  Widget _stat(BuildContext context, String value, String label) {
    final c = context.brand;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
        ],
      ),
    );
  }
}
