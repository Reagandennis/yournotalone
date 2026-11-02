import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../toolkit/toolkit_ui.dart';
import 'sleep_content.dart';

/// One night, as the person remembers it. Times are minutes after
/// midnight so a bedtime of 23:30 and a wake of 06:45 subtract cleanly.
class SleepNight {
  const SleepNight({
    required this.date,
    required this.bedMinutes,
    required this.wakeMinutes,
    required this.latency,
    required this.awake,
    required this.quality,
  });

  /// The morning it was logged, yyyy-mm-dd.
  final String date;
  final int bedMinutes;
  final int wakeMinutes;

  /// Minutes it took to fall asleep.
  final int latency;

  /// Minutes awake in the night after first falling asleep.
  final int awake;

  /// 1 (awful) to 5 (great).
  final int quality;

  int get timeInBed => (wakeMinutes - bedMinutes + 1440) % 1440;
  int get totalSleep => (timeInBed - latency - awake).clamp(0, timeInBed);

  /// The number sleep clinics watch: sleep as a share of time in bed.
  double get efficiency => timeInBed == 0 ? 0 : totalSleep / timeInBed;

  Map<String, dynamic> toJson() => {
    'date': date,
    'bed': bedMinutes,
    'wake': wakeMinutes,
    'latency': latency,
    'awake': awake,
    'quality': quality,
  };

  static SleepNight fromJson(Map<String, dynamic> m) => SleepNight(
    date: m['date'] as String,
    bedMinutes: m['bed'] as int,
    wakeMinutes: m['wake'] as int,
    latency: m['latency'] as int,
    awake: m['awake'] as int,
    quality: m['quality'] as int,
  );
}

const _key = 'sleep.diary';
const _keep = 28;

Future<List<SleepNight>> loadSleepNights() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return [];
  return [
    for (final m in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
      SleepNight.fromJson(m),
  ];
}

Future<void> saveSleepNights(List<SleepNight> nights) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _key,
    jsonEncode([for (final n in nights.take(_keep)) n.toJson()]),
  );
}

/// What a week of nights adds up to, and what to do about it. Pure, so
/// the advice can be tested without a screen.
class SleepSummary {
  SleepSummary(List<SleepNight> nights)
    : nights = nights.take(7).toList(),
      count = nights.take(7).length;

  final List<SleepNight> nights;
  final int count;

  double get averageEfficiency => count == 0
      ? 0
      : nights.map((n) => n.efficiency).reduce((a, b) => a + b) / count;

  int get averageSleep => count == 0
      ? 0
      : nights.map((n) => n.totalSleep).reduce((a, b) => a + b) ~/ count;

  int get averageWake => count == 0
      ? 420
      : nights.map((n) => n.wakeMinutes).reduce((a, b) => a + b) ~/ count;

  /// A suggested sleep window (bed, wake) in minutes after midnight, the
  /// way sleep-restriction therapy sets one: about the sleep you actually
  /// get plus half an hour, never under five and a half hours, ending at
  /// your usual wake time.
  (int, int)? get window {
    if (count < 5) return null;
    final length = (averageSleep + 30).clamp(330, 600);
    return ((averageWake - length + 1440) % 1440, averageWake);
  }

  /// The advice in English; screens use [verdictIn].
  String get verdict =>
      verdictIn(lookupAppLocalizations(const Locale('en')));

  String verdictIn(AppLocalizations l10n) {
    if (count == 0) return l10n.sleepDiaryVerdictEmpty;
    final pct = (averageEfficiency * 100).round();
    if (count < 5) return l10n.sleepDiaryVerdictEarly(pct);
    if (averageEfficiency >= 0.85) return l10n.sleepDiaryVerdictGood(pct);
    return l10n.sleepDiaryVerdictLow(pct);
  }
}

String _fmt(int minutes) {
  final h = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String _hours(AppLocalizations l10n, int minutes) =>
    l10n.sleepDiaryHoursMinutes(
      minutes ~/ 60,
      (minutes % 60).toString().padLeft(2, '0'),
    );

/// Log last night in a minute. After a week it shows sleep efficiency
/// and suggests a sleep window — the core of CBT for insomnia.
class SleepDiaryScreen extends StatefulWidget {
  const SleepDiaryScreen({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  State<SleepDiaryScreen> createState() => _SleepDiaryScreenState();
}

class _SleepDiaryScreenState extends State<SleepDiaryScreen> {
  List<SleepNight>? _nights;
  bool _logging = false;
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  double _latency = 15;
  double _awake = 10;
  int _quality = 3;

  List<String> _qualities(AppLocalizations l10n) => [
    l10n.sleepDiaryQualityAwful,
    l10n.sleepDiaryQualityPoor,
    l10n.sleepDiaryQualityOkay,
    l10n.sleepDiaryQualityGood,
    l10n.sleepDiaryQualityGreat,
  ];

  @override
  void initState() {
    super.initState();
    loadSleepNights().then((n) {
      if (mounted) setState(() => _nights = n);
    });
  }

  String get _today {
    final d = widget.clock?.call() ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pick(bool bed) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: bed ? _bed : _wake,
      helpText: bed
          ? context.l10n.sleepDiaryLightsOut
          : context.l10n.sleepDiaryWoke,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (bed) {
        _bed = picked;
      } else {
        _wake = picked;
      }
    });
    setState(() => bed ? _bed = picked : _wake = picked);
  }

  Future<void> _save() async {
    final night = SleepNight(
      date: _today,
      bedMinutes: _bed.hour * 60 + _bed.minute,
      wakeMinutes: _wake.hour * 60 + _wake.minute,
      latency: _latency.round(),
      awake: _awake.round(),
      quality: _quality,
    );
    final nights = [night, ..._nights!.where((n) => n.date != _today)];
    await saveSleepNights(nights);
    if (!mounted) return;
    setState(() {
      _nights = nights;
      _logging = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.sleepDiaryLogged(
              _hours(context.l10n, night.totalSleep),
              (night.efficiency * 100).round(),
            ),
          ),
        ),
      );
  }

  Widget _timeRow(String label, TimeOfDay t, bool bed, VoidCallback onTap) {
    return ToolkitChoice(
      title: label,
      detail: t.format(context),
      icon: bed ? Icons.bedtime_rounded : Icons.wb_sunny_rounded,
      selected: false,
      onTap: onTap,
      trailing: Icons.edit_rounded,
    );
  }

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged,
  ) {
    final c = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.sleepDiarySliderLabel(label, value.round()),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        Slider(
          value: value,
          min: 0,
          max: max,
          divisions: (max / 5).round(),
          activeColor: c.accent(sleepAccent),
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<Widget> _form(AppLocalizations l10n) => [
    ToolkitSection(
      title: l10n.sleepDiaryLastNight,
      subtitle: l10n.sleepDiaryLastNightHint,
    ),
    _timeRow(l10n.sleepDiaryLightsOut, _bed, true, () => _pick(true)),
    _timeRow(l10n.sleepDiaryWoke, _wake, false, () => _pick(false)),
    const SizedBox(height: 8),
    _slider(
      l10n.sleepDiaryTimeToFallAsleep,
      _latency,
      120,
      (v) => setState(() => _latency = v),
    ),
    _slider(
      l10n.sleepDiaryAwakeInNight,
      _awake,
      180,
      (v) => setState(() => _awake = v),
    ),
    const SizedBox(height: 6),
    Text(
      l10n.sleepDiaryHowDidYouFeel,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: context.brand.ink,
      ),
    ),
    const SizedBox(height: 10),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, q) in _qualities(l10n).indexed)
          ToolkitPill(
            label: q,
            selected: _quality == i + 1,
            onTap: () => setState(() => _quality = i + 1),
          ),
      ],
    ),
  ];

  List<Widget> _overview(List<SleepNight> nights) {
    final c = context.brand;
    final l10n = context.l10n;
    final summary = SleepSummary(nights);
    final window = summary.window;
    return [
      ToolkitSection(
        title: l10n.sleepDiaryYourNights,
        subtitle: l10n.sleepDiaryYourNightsHint,
      ),
      ToolkitNote(
        tint: c.tint(sleepAccent, 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Stat(
                  label: l10n.sleepDiaryStatEfficiency,
                  value: summary.count == 0
                      ? '—'
                      : '${(summary.averageEfficiency * 100).round()}%',
                ),
                _Stat(
                  label: l10n.sleepDiaryStatAsleep,
                  value: summary.count == 0
                      ? '—'
                      : _hours(l10n, summary.averageSleep),
                ),
                _Stat(
                  label: l10n.sleepDiaryStatNights,
                  value: l10n.sleepDiaryNightsOfSeven(summary.count),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              summary.verdictIn(l10n),
              style: TextStyle(
                fontSize: 13,
                color: c.ink,
                height: 1.5,
              ),
            ),
            if (window != null) ...[
              const SizedBox(height: 10),
              Text(
                l10n.sleepDiarySuggestedWindow(
                  _fmt(window.$1),
                  _fmt(window.$2),
                ),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: c.accent(sleepAccent),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      if (nights.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            l10n.sleepDiaryEmpty,
            style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.5),
          ),
        )
      else
        for (final n in nights.take(14))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(n.efficiency * 100).round()}%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: n.efficiency >= 0.85
                              ? c.accent(sleepAccent)
                              : c.red,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.sleepDiaryNightSummary(
                              _fmt(n.bedMinutes),
                              _fmt(n.wakeMinutes),
                              _hours(l10n, n.totalSleep),
                            ),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: c.ink,
                            ),
                          ),
                          Text(
                            l10n.sleepDiaryNightDetail(
                              n.date,
                              n.latency,
                              n.awake,
                              _qualities(l10n)[n.quality - 1].toLowerCase(),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nights = _nights;
    if (nights == null) {
      return ToolkitScaffold(
        accent: sleepAccent,
        title: l10n.sleepDiaryTitle,
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    final loggedToday = nights.any((n) => n.date == _today);
    return ToolkitScaffold(
      accent: sleepAccent,
      title: l10n.sleepDiaryTitle,
      bottom: _logging
          ? Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _logging = false),
                  child: Text(l10n.commonCancel),
                ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(l10n.sleepDiarySaveNight),
                  ),
                ),
              ],
            )
          : ElevatedButton.icon(
              onPressed: () => setState(() => _logging = true),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                loggedToday
                    ? l10n.sleepDiaryEditToday
                    : l10n.sleepDiaryLogLastNight,
              ),
            ),
      children: _logging ? _form(l10n) : _overview(nights),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
