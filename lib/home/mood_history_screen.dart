import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import 'home_ui.dart';
import 'mood_repository.dart';
import 'mood_scale.dart';

/// Everything the daily check-in has added up to: the last month at a
/// glance, a few numbers worth knowing, then every entry in order.
class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key, this.repository});

  /// Injectable so the screen can be driven with known check-ins.
  final MoodRepository? repository;

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  static const _stripDays = 30;

  late final _repo = widget.repository ?? MoodRepository();
  List<MoodEntry>? _entries;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _entries = null;
      _error = false;
    });
    try {
      final entries = await _repo.fetchHistory();
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  /// How many days in a row up to today have a check-in.
  int _streak(Map<String, MoodEntry> byDate) {
    final today = DateTime.now();
    var days = 0;
    for (var back = 0; back < 400; back++) {
      final key = MoodRepository.dateKey(
        DateTime(today.year, today.month, today.day - back),
      );
      if (!byDate.containsKey(key)) {
        // Today not being logged yet shouldn't break yesterday's streak.
        if (back == 0) continue;
        break;
      }
      days++;
    }
    return days;
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

  /// One column per day for the last month: taller and warmer as the day
  /// went better, a flat grey stub for days with no check-in.
  Widget _strip(Map<String, MoodEntry> byDate) {
    final today = DateTime.now();
    return SizedBox(
      height: 77,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var back = _stripDays - 1; back >= 0; back--)
            Builder(builder: (context) {
              final day = DateTime(today.year, today.month, today.day - back);
              final entry = byDate[MoodRepository.dateKey(day)];
              final level = entry == null ? null : moodLevels[entry.index];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        // Tallest bar (71) plus the gap under it stays
                        // inside the strip's height.
                        height: entry == null
                            ? 6
                            : 16 + (entry.index + 1) * 11.0,
                        decoration: BoxDecoration(
                          color: level?.color ?? const Color(0xFFEDEDF2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.5, color: Brand.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(MoodEntry entry) {
    final level = moodLevels[entry.index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Brand.border, width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: level.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(level.icon, size: 23, color: level.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _dateLabel(entry.date),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Brand.ink,
                ),
              ),
            ),
            Text(
              level.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: level.color,
              ),
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
            'Couldn\'t load your check-ins.',
            style: TextStyle(fontSize: 14, color: Brand.textMuted),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    }
    final entries = _entries;
    if (entries == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (entries.isEmpty) {
      return const Text(
        'No check-ins yet. Tap a face on the home screen and this fills '
        'in — one day at a time.',
        style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.55),
      );
    }

    final byDate = {
      for (final entry in entries) MoodRepository.dateKey(entry.date): entry,
    };
    final average =
        entries.map((e) => e.index + 1).reduce((a, b) => a + b) /
            entries.length;
    final counts = List.filled(moodLevels.length, 0);
    for (final entry in entries) {
      counts[entry.index]++;
    }
    var common = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] > counts[common]) common = i;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Last 30 days'),
        const SizedBox(height: 12),
        _strip(byDate),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _dateLabel(DateTime.now()
                  .subtract(const Duration(days: _stripDays - 1))),
              style: const TextStyle(fontSize: 11, color: Brand.textMuted),
            ),
            const Text(
              'Today',
              style: TextStyle(fontSize: 11, color: Brand.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0x0A191919),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _stat('${entries.length}', 'check-ins'),
              _stat('${_streak(byDate)}', 'day streak'),
              _stat(average.toStringAsFixed(1), 'average'),
              _stat(moodLevels[common].label, 'most days'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Every check-in'),
        const SizedBox(height: 12),
        for (final entry in entries) _entryRow(entry),
      ],
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
                  'Mood history',
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
                  'Hard weeks feel permanent while you\'re in them. This is '
                  'the record that says otherwise.',
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
