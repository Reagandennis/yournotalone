import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import 'recovery_repository.dart';

/// What the craving log adds up to: which triggers keep coming back,
/// when in the day they land, and how hard they've been hitting.
class TriggerInsightsScreen extends StatefulWidget {
  const TriggerInsightsScreen({super.key, this.repository});

  /// Injectable so the screen can be driven with known logs.
  final RecoveryRepository? repository;

  @override
  State<TriggerInsightsScreen> createState() => _TriggerInsightsScreenState();
}

class _TriggerInsightsScreenState extends State<TriggerInsightsScreen> {
  static const _days = 90;
  static const _partsOfDay = ['Morning', 'Afternoon', 'Evening', 'Night'];

  late final _repo = widget.repository ?? RecoveryRepository();
  List<CravingLog>? _logs;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _logs = null;
      _error = false;
    });
    try {
      final logs = await _repo.fetchCravings(days: _days);
      if (mounted) setState(() => _logs = logs);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  /// Counts per key, biggest first.
  List<MapEntry<String, int>> _ranked(
      List<CravingLog> logs, String Function(CravingLog) by) {
    final counts = <String, int>{};
    for (final log in logs) {
      counts[by(log)] = (counts[by(log)] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  Widget _bar(String label, int count, int max, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Brand.ink),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0x0A191919),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: max == 0 ? 0 : count / max,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Brand.textMuted,
              ),
            ),
          ),
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

  Widget _body() {
    if (_error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Couldn\'t load your craving log.',
            style: TextStyle(fontSize: 14, color: Brand.textMuted),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    }
    final logs = _logs;
    if (logs == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    if (logs.isEmpty) {
      return const Text(
        'Nothing logged in the last three months. Log a craving as it '
        'happens and the pattern shows up here — usually sooner than '
        'you\'d expect.',
        style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.55),
      );
    }

    final triggers = _ranked(logs, (log) => log.trigger);
    final times = _ranked(logs, (log) => log.partOfDay);
    final timeCounts = {for (final e in times) e.key: e.value};
    final average =
        logs.map((l) => l.intensity).reduce((a, b) => a + b) / logs.length;
    final worst = logs.map((l) => l.intensity).reduce((a, b) => a > b ? a : b);
    final maxTrigger = triggers.first.value;
    final maxTime = times.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0x0A191919),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _stat('${logs.length}', 'logged'),
              _stat(average.toStringAsFixed(1), 'average'),
              _stat('$worst', 'strongest'),
              _stat(times.first.key, 'usual time'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x1FFAB414),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18, color: Brand.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${triggers.first.key} in the '
                  '${times.first.key.toLowerCase()} is your pattern. '
                  'That\'s the one worth planning for.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Brand.ink,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'What sets them off'),
        const SizedBox(height: 12),
        for (final entry in triggers)
          _bar(entry.key, entry.value, maxTrigger, Brand.red),
        const SizedBox(height: 20),
        const SectionHeader(title: 'When they land'),
        const SizedBox(height: 12),
        for (final part in _partsOfDay)
          _bar(part, timeCounts[part] ?? 0, maxTime, Brand.blue),
        const SizedBox(height: 22),
        const Text(
          'Every one of these was a craving you sat with instead of acting '
          'on. That is the whole skill.',
          style: TextStyle(
            fontSize: 12.5,
            color: Brand.textMuted,
            height: 1.5,
          ),
        ),
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
                  'Trigger insights',
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
                  'Cravings feel random from the inside. Logged, they stop '
                  'being random — and a pattern you can see is one you can '
                  'plan around.',
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
