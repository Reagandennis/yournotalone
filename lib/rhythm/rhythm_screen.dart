import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
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
    final l10n = context.l10n;
    final r = _rhythm;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.rhythmTitle)),
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
            rhythmHeadline(r, l10n),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: c.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            rhythmDetail(r, l10n),
            style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          RhythmWeek(rhythm: r, size: 28),
          const SizedBox(height: 28),
          _heading(context, l10n.rhythmWeeklyGoalHeading),
          const SizedBox(height: 6),
          Text(
            l10n.rhythmWeeklyGoalBody,
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
            l10n.rhythmDaysAWeek(r.goal),
            style: TextStyle(fontSize: 12.5, color: c.textMuted),
          ),
          const SizedBox(height: 28),
          _heading(context, l10n.rhythmLastTwelveWeeks),
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
              _stat(
                context,
                '${r.weeksInRhythm}',
                l10n.rhythmStatWeekRhythm(r.weeksInRhythm),
              ),
              _stat(
                context,
                '${r.bestWeeks}',
                l10n.rhythmStatLongest(r.bestWeeks),
              ),
              _stat(
                context,
                '${r.totalDays}',
                l10n.rhythmStatDaysInTotal(r.totalDays),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _heading(context, l10n.rhythmWhatCounts),
          const SizedBox(height: 8),
          for (final (icon, text) in [
            (Icons.mood_rounded, l10n.rhythmCountsMood),
            (Icons.self_improvement_rounded, l10n.rhythmCountsPractice),
            (Icons.graphic_eq_rounded, l10n.rhythmCountsSound),
            (Icons.edit_note_rounded, l10n.rhythmCountsJournal),
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
            l10n.rhythmNothingIsLost,
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
