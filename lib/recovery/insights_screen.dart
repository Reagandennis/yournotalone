import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
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
  static const _partsOfDay = CravingLog.partsOfDay;

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

  /// [color] is declared, as a pillar colour; it's drawn through
  /// [BrandColors.art] so the bar stands out on either page.
  Widget _bar(String label, int count, int max, Color color) {
    final c = context.brand;
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
              style: TextStyle(fontSize: 13, color: c.ink),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: c.tint(Pillars.black, 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: max == 0 ? 0 : count / max,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: c.art(color),
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
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ),
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

  Widget _body() {
    final c = context.brand;
    final l10n = context.l10n;
    if (_error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.triggerInsightsLoadError,
            style: TextStyle(fontSize: 14, color: c.textMuted),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: Text(l10n.commonTryAgain)),
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
      return Text(
        l10n.triggerInsightsEmpty,
        style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.55),
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
            color: c.tint(Pillars.black, 0.04),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              _stat(
                '${logs.length}',
                l10n.triggerInsightsStatLogged(logs.length),
              ),
              _stat(
                average.toStringAsFixed(1),
                l10n.triggerInsightsStatAverage,
              ),
              _stat('$worst', l10n.triggerInsightsStatStrongest),
              _stat(
                CravingLog.partOfDayLabel(l10n, times.first.key),
                l10n.triggerInsightsStatUsualTime,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.tint(Pillars.yellow, 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: c.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.triggerInsightsPattern(
                    recoveryTriggerLabel(l10n, triggers.first.key),
                    times.first.key,
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.ink,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        SectionHeader(title: l10n.triggerInsightsWhatSetsThemOff),
        const SizedBox(height: 12),
        for (final entry in triggers)
          _bar(
            recoveryTriggerLabel(l10n, entry.key),
            entry.value,
            maxTrigger,
            Pillars.red,
          ),
        const SizedBox(height: 20),
        SectionHeader(title: l10n.triggerInsightsWhenTheyLand),
        const SizedBox(height: 12),
        for (final part in _partsOfDay)
          _bar(
            CravingLog.partOfDayLabel(l10n, part),
            timeCounts[part] ?? 0,
            maxTime,
            Pillars.blue,
          ),
        const SizedBox(height: 22),
        Text(
          l10n.triggerInsightsFooter,
          style: TextStyle(
            fontSize: 12.5,
            color: c.textMuted,
            height: 1.5,
          ),
        ),
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
                  context.l10n.triggerInsightsTitle,
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
                  context.l10n.triggerInsightsSubtitle,
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
