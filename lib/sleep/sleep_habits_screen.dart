import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
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
                    label: context.l10n.sleepHabitsYes,
                    selected: yes,
                    onTap: () => _answer(h.id, true),
                  ),
                  const SizedBox(width: 8),
                  ToolkitPill(
                    label: context.l10n.sleepHabitsNo,
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
    final l10n = context.l10n;
    final hits = sleepHabits.where((h) => _yes.contains(h.id)).toList();
    final verdict = switch (hits.length) {
      0 => l10n.sleepHabitsVerdictNone,
      1 || 2 => l10n.sleepHabitsVerdictFew,
      3 || 4 => l10n.sleepHabitsVerdictSome,
      _ => l10n.sleepHabitsVerdictMany,
    };
    return [
      ToolkitSection(
        title: hits.isEmpty
            ? l10n.sleepHabitsAllClear
            : l10n.sleepHabitsToWorkOn(hits.length),
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
        child: Text(l10n.sleepHabitsAnswerAgain),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_loaded) {
      return ToolkitScaffold(
        accent: sleepAccent,
        title: l10n.sleepHabitsTitle,
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    return ToolkitScaffold(
      accent: sleepAccent,
      title: l10n.sleepHabitsTitle,
      bottom: _showResults
          ? null
          : ElevatedButton(
              onPressed: _complete ? _finish : null,
              child: Text(
                _complete
                    ? l10n.sleepHabitsSeeResults
                    : l10n.sleepHabitsAnswered(
                        _yes.length + _no.length,
                        sleepHabits.length,
                      ),
              ),
            ),
      children: _showResults
          ? _results()
          : [
              ToolkitSection(
                title: l10n.sleepHabitsIntroTitle,
                subtitle: l10n.sleepHabitsIntroHint,
              ),
              for (final h in sleepHabits) _question(h),
            ],
    );
  }
}
