import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import 'rhythm.dart';
import 'sunrise_art.dart';

/// Monday-first one-letter weekday names ("M T W T F S S" in English).
List<String> _dayLetters(AppLocalizations l10n) =>
    l10n.rhythmWeekdayLetters.split(' ');

/// The headline for where the week stands. Never about loss: a gap is
/// met with a welcome, and a missed day is just a rest day.
///
/// [l10n] defaults to the app's current language.
String rhythmHeadline(Rhythm r, [AppLocalizations? l10n]) {
  l10n ??= currentL10n();
  final milestone = r.milestoneIn(l10n);
  if (milestone != null) return milestone;
  if (r.welcomeBack) return l10n.rhythmWelcomeBack;
  if (r.goalMet) return l10n.rhythmSunIsUp;
  if (r.daysThisWeek == 0) return l10n.rhythmNewWeek;
  return l10n.rhythmDaysThisWeek(r.daysThisWeek, r.goal);
}

/// The quieter line under it.
String rhythmDetail(Rhythm r, [AppLocalizations? l10n]) {
  l10n ??= currentL10n();
  if (r.isEmpty) return l10n.rhythmAnyStepCounts;
  if (r.welcomeBack) return l10n.rhythmShownUpWelcomeBack(r.totalDays);
  if (r.weeksInRhythm > 0) {
    return l10n.rhythmWeeksAndTotal(r.weeksInRhythm, r.totalDays);
  }
  return l10n.rhythmDaysInTotal(r.totalDays);
}

/// The week's sunrise on Home: the sun climbs with each day shown up,
/// towards the weekly goal.
class RhythmCard extends StatelessWidget {
  const RhythmCard({super.key, required this.rhythm, required this.onTap});

  final Rhythm rhythm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final r = rhythm;
    return Semantics(
      button: true,
      label: context.l10n.rhythmCardSemantics(
        rhythmHeadline(r, context.l10n),
        rhythmDetail(r, context.l10n),
      ),
      excludeSemantics: true,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SunriseArt(progress: r.progress, height: 118),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rhythmHeadline(r, context.l10n),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: c.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rhythmDetail(r, context.l10n),
                      style: TextStyle(fontSize: 12.5, color: c.textMuted),
                    ),
                    const SizedBox(height: 14),
                    RhythmWeek(rhythm: r),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monday to Sunday: a lit sun for each day shown up, a ring for today
/// while it's still open, and a quiet dot otherwise — rest, never a miss.
class RhythmWeek extends StatelessWidget {
  const RhythmWeek({super.key, required this.rhythm, this.size = 22});

  final Rhythm rhythm;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final r = rhythm;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: r.week[i]
                      ? WeekSun(fill: 1, size: size)
                      : i == r.todayIndex
                      ? Center(
                          child: Container(
                            width: size * 0.5,
                            height: size * 0.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: c.textMuted,
                                width: 1.4,
                              ),
                            ),
                          ),
                        )
                      : WeekSun(fill: 0, size: size),
                ),
                const SizedBox(height: 4),
                Text(
                  _dayLetters(context.l10n)[i],
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == r.todayIndex
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: i == r.todayIndex ? c.ink : c.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
