import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
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

/// What a score means, in plain words, and where to go next.
(String, String) stressBand(int score) => switch (score) {
  <= 6 => (
    'Low',
    'You\'re carrying this week fine. Keep whatever recovery you\'ve '
        'got in place — it\'s working.',
  ),
  <= 13 => (
    'Moderate',
    'Noticeable, and worth ten deliberate minutes a day: a sigh '
        'round, a walk, a proper break. Sort one thing that\'s in '
        'your hands.',
  ),
  _ => (
    'High',
    'A lot right now. Bring the body down first — sigh, tense and '
        'release — then look at the load. If it\'s been like this '
        'for weeks, talk to someone; that\'s what the therapist '
        'sessions are for.',
  ),
};

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
                '${i + 1}. ${q.text}',
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
            'Your last check-ins',
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
            '${recent.first.date} → ${recent.last.date} · 0 is calm, 20 is a lot',
            style: TextStyle(fontSize: 11.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = _history;
    if (history == null) {
      return const ToolkitScaffold(
        accent: stressAccent,
        title: 'Stress check-in',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final c = context.brand;
    final result = _result;
    if (result != null) {
      final (band, advice) = stressBand(result);
      return ToolkitScaffold(
        accent: stressAccent,
        title: 'Stress check-in',
        bottom: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
        children: [
          ToolkitNote(
            tint: c.tint(stressAccent, 0.14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$result out of 20 · $band',
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
            'A check-in is a snapshot of one week, not a diagnosis. If the '
            'high scores keep coming, that\'s the signal to talk to someone.',
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
      title: 'Stress check-in',
      bottom: ElevatedButton(
        onPressed: _complete ? _finish : null,
        child: Text(
          _complete
              ? 'See my score'
              : '${_answers.whereType<int>().length} of ${stressQuestions.length} answered',
        ),
      ),
      children: [
        const ToolkitSection(
          title: 'The past week',
          subtitle:
              'Go with your first answer. Once a week, same day, gives '
              'you a line you can actually read.',
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
