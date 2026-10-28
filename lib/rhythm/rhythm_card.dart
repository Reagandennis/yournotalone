import 'package:flutter/material.dart';

import '../brand.dart';
import 'rhythm.dart';
import 'sunrise_art.dart';

const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

/// The headline for where the week stands. Never about loss: a gap is
/// met with a welcome, and a missed day is just a rest day.
String rhythmHeadline(Rhythm r) {
  if (r.milestone != null) return r.milestone!;
  if (r.welcomeBack) return 'Welcome back';
  if (r.goalMet) return 'Your sun is up this week';
  if (r.daysThisWeek == 0) return 'A new week, a new sunrise';
  return '${r.daysThisWeek} of ${r.goal} days this week';
}

/// The quieter line under it.
String rhythmDetail(Rhythm r) {
  if (r.isEmpty) {
    return 'Any small step counts — a check-in, a breath, a few lines.';
  }
  final total = '${r.totalDays} ${r.totalDays == 1 ? 'day' : 'days'} in total';
  if (r.welcomeBack) return 'You\'ve shown up $total. Today can count too.';
  if (r.weeksInRhythm > 0) {
    return '${r.weeksInRhythm}-week rhythm · $total';
  }
  return total;
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
      label: '${rhythmHeadline(r)}. ${rhythmDetail(r)}',
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
                            rhythmHeadline(r),
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
                      rhythmDetail(r),
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
                  _dayLetters[i],
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
