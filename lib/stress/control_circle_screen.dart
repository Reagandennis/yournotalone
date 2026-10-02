import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../cbt/problem_solving_screen.dart';
import '../toolkit/toolkit_links.dart';
import '../toolkit/toolkit_ui.dart';
import 'stress_content.dart';

/// Where a stressor sits: something you can change, something you can
/// only lean on, or something to make peace with.
enum Zone {
  control('Control', 'I can change this', Icons.build_circle_rounded),
  influence('Influence', 'I can lean on it', Icons.record_voice_over_rounded),
  accept('Accept', 'Not mine to move', Icons.spa_rounded);

  const Zone(this.label, this.hint, this.icon);

  final String label;
  final String hint;
  final IconData icon;
}

class Stressor {
  Stressor(this.text, {this.zone});

  final String text;
  Zone? zone;

  Map<String, dynamic> toJson() => {'text': text, 'zone': zone?.name};
  static Stressor fromJson(Map<String, dynamic> m) => Stressor(
    m['text'] as String,
    zone: m['zone'] == null ? null : Zone.values.byName(m['zone'] as String),
  );
}

const _key = 'stress.circle';

Future<List<Stressor>> loadStressors() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return [];
  return [
    for (final m in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
      Stressor.fromJson(m),
  ];
}

Future<void> saveStressors(List<Stressor> items) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, jsonEncode([for (final s in items) s.toJson()]));
}

/// The circles of control: write down what's weighing on you and sort
/// each into control, influence or accept. Effort then goes where it can
/// do something, and the rest gets set down on purpose.
class ControlCircleScreen extends StatefulWidget {
  const ControlCircleScreen({super.key});

  @override
  State<ControlCircleScreen> createState() => _ControlCircleScreenState();
}

class _ControlCircleScreenState extends State<ControlCircleScreen> {
  List<Stressor>? _items;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadStressors().then((i) {
      if (mounted) setState(() => _items = i);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items!.insert(0, Stressor(text));
      _input.clear();
    });
    saveStressors(_items!);
  }

  void _setZone(Stressor s, Zone z) {
    setState(() => s.zone = s.zone == z ? null : z);
    saveStressors(_items!);
  }

  void _remove(Stressor s) {
    setState(() => _items!.remove(s));
    saveStressors(_items!);
  }

  Widget _tile(Stressor s) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.ink,
                        height: 1.4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: c.textMuted,
                    tooltip: 'Remove',
                    onPressed: () => _remove(s),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final z in Zone.values)
                    ToolkitPill(
                      label: z.label,
                      icon: z.icon,
                      selected: s.zone == z,
                      onTap: () => _setZone(s, z),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoneSummary(Zone z, List<Stressor> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final c = context.brand;
    final (advice, action, onTap) = switch (z) {
      Zone.control => (
        'These are yours to move. Pick one — the smallest — and take '
            'the first step this week.',
        'Work one through',
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProblemSolvingScreen())),
      ),
      Zone.influence => (
        'You can\'t decide these, but you can ask, say, or nudge. What '
            'is the one conversation each of these needs?',
        null,
        null,
      ),
      Zone.accept => (
        'Not yours to carry, and carrying them anyway is where a lot of '
            'stress lives. Practise setting them down — it\'s a skill, '
            'not a mood.',
        'Breathe it out',
        () => openBreathing(context, 'Slow exhale', source: 'toolkit:stress'),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ToolkitNote(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(z.icon, size: 18, color: c.ink),
                const SizedBox(width: 8),
                Text(
                  '${z.label} · ${items.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final s in items)
              Text(
                '• ${s.text}',
                style: TextStyle(
                  fontSize: 13,
                  color: c.ink,
                  height: 1.45,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              advice,
              style: TextStyle(
                fontSize: 12.5,
                color: c.textMuted,
                height: 1.45,
              ),
            ),
            if (action != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: onTap, child: Text(action)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const ToolkitScaffold(
        accent: stressAccent,
        title: 'What\'s in your hands',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final sorted = items.where((s) => s.zone != null).length;
    return ToolkitScaffold(
      accent: stressAccent,
      title: 'What\'s in your hands',
      children: [
        const ToolkitSection(
          title: 'Three circles',
          subtitle:
              'Write down everything that\'s weighing on you, then '
              'sort each one. Most stress comes from spending effort in the '
              'outer circles and neglecting the inner one.',
        ),
        TextField(
          controller: _input,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            labelText: 'Something on your mind',
            counterText: '',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _add,
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final s in items) _tile(s),
        if (sorted > 0) ...[
          const SizedBox(height: 10),
          const ToolkitSection(title: 'Where your effort goes'),
          for (final z in Zone.values)
            _zoneSummary(z, items.where((s) => s.zone == z).toList()),
        ],
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Start with whatever came to mind first. Vague is fine — '
              '"work", "money", "mum" — you can sharpen it later.',
              style: TextStyle(
                fontSize: 13,
                color: context.brand.textMuted,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
