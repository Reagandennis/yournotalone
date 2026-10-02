import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../toolkit/toolkit_ui.dart';
import 'sleep_content.dart';

const _key = 'sleep.habits';

/// Ten yes/no questions about the things that quietly wreck sleep, and a
/// fix for each yes. The last answers are kept so the fixes stay in view.
class SleepHabitsScreen extends StatefulWidget {
  const SleepHabitsScreen({super.key});

  @override
  State<SleepHabitsScreen> createState() => _SleepHabitsScreenState();
}

class _SleepHabitsScreenState extends State<SleepHabitsScreen> {
  final _yes = <String>{};
  final _no = <String>{};
  bool _showResults = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final raw = prefs.getString(_key);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _yes.addAll((m['yes'] as List).cast<String>());
        _no.addAll((m['no'] as List).cast<String>());
        _showResults = _yes.length + _no.length == sleepHabits.length;
      }
      if (mounted) setState(() => _loaded = true);
    });
  }

  bool get _complete => _yes.length + _no.length == sleepHabits.length;

  void _answer(String id, bool yes) {
    setState(() {
      _yes.remove(id);
      _no.remove(id);
      (yes ? _yes : _no).add(id);
    });
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({'yes': _yes.toList(), 'no': _no.toList()}),
    );
    if (mounted) setState(() => _showResults = true);
  }

  Widget _question(SleepHabit h) {
    final c = context.brand;
    final yes = _yes.contains(h.id);
    final no = _no.contains(h.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(h.icon, size: 20, color: c.accent(sleepAccent)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      h.question,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.ink,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ToolkitPill(
                    label: 'Yes',
                    selected: yes,
                    onTap: () => _answer(h.id, true),
                  ),
                  const SizedBox(width: 8),
                  ToolkitPill(
                    label: 'No',
                    selected: no,
                    onTap: () => _answer(h.id, false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _results() {
    final c = context.brand;
    final hits = sleepHabits.where((h) => _yes.contains(h.id)).toList();
    final verdict = switch (hits.length) {
      0 =>
        'Nothing here is working against you. If sleep is still hard, '
            'the diary and the 20-minute rule are the next places to look.',
      1 || 2 =>
        'One or two habits to change — small, and they tend to pay '
            'back within a week or two.',
      3 || 4 =>
        'A few things are stacking up against your nights. Pick the '
            'easiest one first; momentum matters more than order.',
      _ =>
        'Quite a lot is working against you, which is actually good '
            'news: there\'s a lot of room to improve without anything '
            'drastic. Start with the wake time.',
    };
    return [
      ToolkitSection(
        title: hits.isEmpty ? 'All clear' : '${hits.length} of 10 to work on',
        subtitle: verdict,
      ),
      for (final h in hits)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c.tint(sleepAccent, 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      h.icon,
                      size: 19,
                      color: c.accent(sleepAccent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      h.tip,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.ink,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => setState(() => _showResults = false),
        child: const Text('Answer again'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const ToolkitScaffold(
        accent: sleepAccent,
        title: 'Sleep habits check',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    return ToolkitScaffold(
      accent: sleepAccent,
      title: 'Sleep habits check',
      bottom: _showResults
          ? null
          : ElevatedButton(
              onPressed: _complete ? _finish : null,
              child: Text(
                _complete
                    ? 'See what to change'
                    : '${_yes.length + _no.length} of ${sleepHabits.length} answered',
              ),
            ),
      children: _showResults
          ? _results()
          : [
              const ToolkitSection(
                title: 'Honest answers, please',
                subtitle:
                    'Most of these are ordinary — everyone has a '
                    'few. Each yes comes with a specific, small change.',
              ),
              for (final h in sleepHabits) _question(h),
            ],
    );
  }
}
