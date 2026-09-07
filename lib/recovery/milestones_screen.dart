import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import 'recovery_repository.dart';

/// Every marker on the way, per commitment: the ones already behind you,
/// the one you're walking toward, and what's still ahead.
class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({super.key, this.repository});

  /// Injectable so the screen can be driven with known commitments.
  final RecoveryRepository? repository;

  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  late final _repo = widget.repository ?? RecoveryRepository();
  List<RecoveryHabit>? _habits;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _habits = null;
      _error = false;
    });
    try {
      final habits = await _repo.fetchHabits();
      if (mounted) setState(() => _habits = habits);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  String _reachedOn(RecoveryHabit habit, int days) {
    final day = habit.dayOne.add(Duration(days: days - 1));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final year = day.year == DateTime.now().year ? '' : ' ${day.year}';
    return '${day.day} ${months[day.month - 1]}$year';
  }

  Widget _milestoneRow(RecoveryHabit habit, int days, String label,
      {required bool last}) {
    final reached = habit.daysIn >= days;
    final isNext = habit.nextMilestone?.$1 == days;
    final color = reached
        ? Brand.blue
        : isNext
            ? Brand.yellow
            : Brand.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: reached ? Brand.blue : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.8),
                ),
                child: reached
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : null,
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 2,
                    color: reached ? Brand.blue : Brand.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: reached || isNext
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: reached || isNext ? Brand.ink : Brand.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reached
                        ? 'Reached ${_reachedOn(habit, days)}'
                        : '${days - habit.daysIn} '
                            '${days - habit.daysIn == 1 ? 'day' : 'days'} to go',
                    style: TextStyle(
                      fontSize: 12,
                      color: isNext ? Brand.ink : Brand.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habitCard(RecoveryHabit habit) {
    final reached =
        recoveryMilestones.where((m) => habit.daysIn >= m.$1).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: Brand.border, width: 1.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$reached of ${recoveryMilestones.length} reached'
                        '${habit.bestStreakDays > habit.daysIn ? ' · best '
                            '${habit.bestStreakDays} days' : ''}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Brand.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Day ${habit.daysIn}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Brand.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final (i, milestone) in recoveryMilestones.indexed)
              _milestoneRow(
                habit,
                milestone.$1,
                milestone.$2,
                last: i == recoveryMilestones.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Couldn\'t load your commitments.',
            style: TextStyle(fontSize: 14, color: Brand.textMuted),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    }
    final habits = _habits;
    if (habits == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (habits.isEmpty) {
      return const Text(
        'No commitments yet. Add one on the recovery screen and every '
        'marker below starts counting from today.',
        style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.55),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final habit in habits) _habitCard(habit)],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  'Milestones',
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
                  'Days add up whether or not anyone claps. Here they are, '
                  'counted.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Brand.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                _body(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
