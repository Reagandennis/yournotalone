import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../discover/content_index.dart';
import '../home/home_ui.dart';
import 'course_catalog.dart';
import 'course_progress.dart';

/// One course: its days in order, what's done, what's today, and what
/// opens tomorrow.
class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.course});

  final Course course;

  static Route<void> route(Course course) =>
      MaterialPageRoute(builder: (_) => CourseScreen(course: course));

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  Course get course => widget.course;

  @override
  void initState() {
    super.initState();
    CourseStore.instance.load();
  }

  void _start(int day) {
    final opened = openContent(
      context,
      course.days[day].item,
      source: 'course:${course.id}',
    );
    // Only a day that was actually started counts as done.
    if (opened) CourseStore.instance.completeDay(course, day);
  }

  Widget _day(int i, CourseProgress progress, DateTime now) {
    final c = context.brand;
    final day = course.days[i];
    final item = day.item;
    final done = progress.done.containsKey(i);
    final open = progress.isOpen(course, i, now);
    final isNext = progress.nextDay(course) == i;
    final locked = item.premium && !isPremiumUser();
    final status = done
        ? 'Done'
        : isNext && !open
        ? 'Opens tomorrow'
        : !open
        ? 'Day ${i + 1}'
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isNext && open ? c.tint(course.accent, 0.08) : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isNext && open ? c.accent(course.accent) : c.border,
            width: 1.2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: open ? () => _start(i) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: done
                        ? c.accent(course.accent)
                        : c.tint(course.accent, 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: Colors.white,
                          )
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.accent(course.accent),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: open ? c.ink : c.textMuted,
                              ),
                            ),
                          ),
                          if (locked && !done) ...[
                            const SizedBox(width: 6),
                            const PremiumChip(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        day.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textMuted,
                          height: 1.35,
                        ),
                      ),
                      if (status != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: done ? c.accent(course.accent) : c.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isNext && open)
                  Icon(
                    Icons.play_circle_fill_rounded,
                    size: 30,
                    color: c.accent(course.accent),
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
    builder: (context, _) => ValueListenableBuilder(
      valueListenable: CourseStore.instance,
      builder: (context, _, _) => _page(context),
    ),
  );

  Widget _page(BuildContext context) {
    final c = context.brand;
    final progress = CourseStore.instance.of(course);
    final now = DateTime.now();
    final finished = progress.finished(course);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                const Align(alignment: Alignment.centerLeft, child: BackChip()),
                const SizedBox(height: 20),
                Text(
                  course.title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 14),
                Text(
                  course.blurb,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.done.length / course.days.length,
                    minHeight: 8,
                    color: c.accent(course.accent),
                    backgroundColor: c.tint(course.accent, 0.12),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  finished
                      ? 'All ${course.days.length} days done. Come back to '
                            'any of them whenever you need.'
                      : '${progress.done.length} of ${course.days.length} '
                            'days done · one new step each day',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: c.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < course.days.length; i++)
                  _day(i, progress, now),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A course as a card: progress if started, the pitch if not. Used on
/// Home and Explore.
class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course, this.suggested = false});

  final Course course;

  /// Shown as a suggestion ("Picked for you") rather than in a list.
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return ValueListenableBuilder(
      valueListenable: CourseStore.instance,
      builder: (context, _, _) {
        final progress = CourseStore.instance.of(course);
        final next = progress.nextDay(course);
        final now = DateTime.now();
        final String line;
        if (!progress.started) {
          line = suggested
              ? 'Picked for you · ${course.days.length} days'
              : '${course.days.length} days · a step a day';
        } else if (next == null) {
          line = 'Finished · all ${course.days.length} days';
        } else if (progress.isOpen(course, next, now)) {
          line = 'Day ${next + 1} of ${course.days.length} · ready today';
        } else {
          line = 'Day ${next + 1} opens tomorrow';
        }
        return Material(
          color: c.tint(course.accent, 0.08),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(CourseScreen.route(course)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress.done.length / course.days.length,
                          strokeWidth: 3.5,
                          color: c.accent(course.accent),
                          backgroundColor: c.tint(course.accent, 0.16),
                        ),
                        Icon(
                          course.icon,
                          size: 20,
                          color: c.accent(course.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          line,
                          style: TextStyle(fontSize: 12.5, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: c.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
