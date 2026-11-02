import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../toolkit/toolkit_ui.dart';
import 'stress_content.dart';

/// One check-in: the day and the score out of 20.
class StressCheckin {
  const StressCheckin(this.date, this.score);

  final String date;
  final int score;

  Map<String, dynamic> toJson() => {'date': date, 'score': score};
  static StressCheckin fromJson(Map<String, dynamic> m) =>
      StressCheckin(m['date'] as String, m['score'] as int);
}

const _key = 'stress.checkins';

Future<List<StressCheckin>> loadStressCheckins() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return [];
  return [
    for (final m in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
      StressCheckin.fromJson(m),
  ];
}

Future<void> saveStressCheckins(List<StressCheckin> items) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _key,
    jsonEncode([for (final c in items.take(30)) c.toJson()]),
  );
}

/// Adds up the answers (0–4 each), counting the coping questions the
/// other way. 0–20.
int stressScore(List<int> answers) {
  var total = 0;
  for (final (i, a) in answers.indexed) {
    total += stressQuestions[i].reversed ? 4 - a : a;
  }
  return total;
}

/// What a score means, in plain words, and where to go next. In the
/// app's current language unless [l10n] is given.
(String, String) stressBand(int score, [AppLocalizations? l10n]) {
  final l = l10n ?? currentL10n();
  return switch (score) {
    <= 6 => (l.stressBandLow, l.stressBandLowAdvice),
    <= 13 => (l.stressBandModerate, l.stressBandModerateAdvice),
    _ => (l.stressBandHigh, l.stressBandHighAdvice),
  };
}

/// Five questions about the past week, scored and kept, so the trend is
/// visible over time.
class StressCheckinScreen extends StatefulWidget {
  const StressCheckinScreen({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  State<StressCheckinScreen> createState() => _StressCheckinScreenState();
}

class _StressCheckinScreenState extends State<StressCheckinScreen> {
  List<StressCheckin>? _history;
  final _answers = List<int?>.filled(stressQuestions.length, null);
  int? _result;

  @override
  void initState() {
    super.initState();
    loadStressCheckins().then((h) {
      if (mounted) setState(() => _history = h);
    });
  }

  bool get _complete => _answers.every((a) => a != null);

  String get _today {
    final d = widget.clock?.call() ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _finish() async {
    final score = stressScore(_answers.cast<int>());
    final history = [
      StressCheckin(_today, score),
      ..._history!.where((c) => c.date != _today),
    ];
    await saveStressCheckins(history);
    if (!mounted) return;
    setState(() {
      _history = history;
      _result = score;
    });
  }

  Widget _question(int i) {
    final c = context.brand;
    final q = stressQuestions[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.stressCheckinQuestion(i + 1, q.text),
                style: TextStyle(
                  fontSize: 14,
                  color: c.ink,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (v, label) in stressAnswers.indexed)
                    ToolkitPill(
                      label: label,
                      selected: _answers[i] == v,
                      onTap: () => setState(() => _answers[i] = v),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trend(List<StressCheckin> history) {
    final c = context.brand;
    final recent = history.take(8).toList().reversed.toList();
    return ToolkitNote(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.stressCheckinHistoryTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final checkin in recent)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${checkin.score}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: c.textMuted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            height: 6 + checkin.score * 2.2,
                            decoration: BoxDecoration(
                              color: c.art(
                                checkin.score > 13
                                    ? Pillars.red
                                    : checkin.score > 6
                                    ? stressAccent
                                    : const Color(0xFF3E9B5B),
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.stressCheckinHistoryRange(
              recent.first.date,
              recent.last.date,
            ),
            style: TextStyle(fontSize: 11.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    final l10n = context.l10n;
    if (history == null) {
      return ToolkitScaffold(
        accent: stressAccent,
        title: l10n.stressCheckinTitle,
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    final c = context.brand;
    final result = _result;
    if (result != null) {
      final (band, advice) = stressBand(result, l10n);
      return ToolkitScaffold(
        accent: stressAccent,
        title: l10n.stressCheckinTitle,
        bottom: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonDone),
        ),
        children: [
          ToolkitNote(
            tint: c.tint(stressAccent, 0.14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.stressCheckinScore(result, band),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  advice,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.ink,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (history.length > 1) _trend(history),
          const SizedBox(height: 16),
          Text(
            l10n.stressCheckinDisclaimer,
            style: TextStyle(
              fontSize: 12.5,
              color: c.textMuted,
              height: 1.5,
            ),
          ),
        ],
      );
    }
    return ToolkitScaffold(
      accent: stressAccent,
      title: l10n.stressCheckinTitle,
      bottom: ElevatedButton(
        onPressed: _complete ? _finish : null,
        child: Text(
          _complete
              ? l10n.stressCheckinSeeScore
              : l10n.stressCheckinAnswered(
                  _answers.whereType<int>().length,
                  stressQuestions.length,
                ),
        ),
      ),
      children: [
        ToolkitSection(
          title: l10n.stressCheckinSectionTitle,
          subtitle: l10n.stressCheckinSectionBody,
        ),
        if (history.isNotEmpty) ...[
          _trend(history),
          const SizedBox(height: 18),
        ],
        for (var i = 0; i < stressQuestions.length; i++) _question(i),
      ],
    );
  }
}
