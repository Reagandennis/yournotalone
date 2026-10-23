import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import 'feeling_store.dart';
import 'practice_repository.dart';

/// Everything you've actually done in the app: minutes practised, the run
/// of days, and every session in order.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, this.repository});

  /// Injectable so the screen can be driven with known sessions.
  final PracticeRepository? repository;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  static const _stripDays = 30;

  late final _repo = widget.repository ?? PracticeRepository();
  List<PracticeSession>? _sessions;
  bool _error = false;

  /// "You felt better after 8 of your last 10 sessions", once there are
  /// enough answers to say it.
  String? _feelingLine;

  @override
  void initState() {
    super.initState();
    _load();
    FeelingStore.instance.recent().then((records) {
      if (mounted) {
        setState(() => _feelingLine = FeelingStore.summarise(records).line);
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _sessions = null;
      _error = false;
    });
    try {
      final sessions = await _repo.fetchRecent();
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final year = d.year == now.year ? '' : ' ${d.year}';
    return '${d.day} ${months[d.month - 1]}$year';
  }

  /// Minutes per day for the last month — taller bars for longer practice,
  /// a flat stub for days you didn't.
  Widget _strip(Map<String, double> minutesByDay) {
    final c = context.brand;
    final today = DateTime.now();
    final busiest = minutesByDay.values.isEmpty
        ? 1.0
        : minutesByDay.values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 74,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var back = _stripDays - 1; back >= 0; back--)
            Builder(builder: (context) {
              final day = DateTime(today.year, today.month, today.day - back);
              final minutes =
                  minutesByDay[PracticeRepository.dateKey(day)] ?? 0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    height: minutes == 0
                        ? 6
                        : 12 + (minutes / busiest) * 54,
                    decoration: BoxDecoration(
                      color: minutes == 0
                          ? c.tint(Pillars.black, 0.06)
                          : c.art(Pillars.blue),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    final c = context.brand;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _sessionRow(PracticeSession session) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.tint(session.kind.color, 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(session.kind.icon,
                  size: 20, color: c.accent(session.kind.color)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.kind.label} · '
                    '${_dateLabel(session.completedAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${session.minutes.round()} min',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final c = context.brand;
    if (_error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Couldn\'t load your practice history.',
            style: TextStyle(fontSize: 14, color: c.textMuted),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    }
    final sessions = _sessions;
    if (sessions == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (sessions.isEmpty) {
      return Text(
        'Nothing here yet. Finish a meditation, a breathing session, or a '
        'few minutes of sound, and it starts filling in.',
        style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.55),
      );
    }

    final summary = PracticeRepository.summarise(sessions);
    final minutesByDay = <String, double>{};
    for (final session in sessions) {
      final key = PracticeRepository.dateKey(session.completedAt);
      minutesByDay[key] = (minutesByDay[key] ?? 0) + session.minutes;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Last 30 days'),
        const SizedBox(height: 12),
        _strip(minutesByDay),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: c.tint(Pillars.black, 0.04),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _stat('${summary.sessions}', 'sessions'),
              _stat('${summary.totalMinutes.round()}', 'minutes'),
              _stat('${summary.dayStreak}', 'day streak'),
              _stat('${summary.minutesThisWeek.round()}', 'this week'),
            ],
          ),
        ),
        if (_feelingLine != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.tint(Pillars.red, 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, size: 18, color: c.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _feelingLine!,
                    style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const SectionHeader(title: 'Every session'),
        const SizedBox(height: 12),
        for (final session in sessions) _sessionRow(session),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
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
                  'Your practice',
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
                  'Minutes nobody else counted. They still happened.',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
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
