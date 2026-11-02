import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../cbt/problem_solving_screen.dart';
import '../toolkit/toolkit_links.dart';
import '../toolkit/toolkit_ui.dart';
import 'stress_content.dart';

/// Where a stressor sits: something you can change, something you can
/// only lean on, or something to make peace with.
enum Zone {
  control(Icons.build_circle_rounded),
  influence(Icons.record_voice_over_rounded),
  accept(Icons.spa_rounded);

  const Zone(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    Zone.control => l10n.controlCircleZoneControl,
    Zone.influence => l10n.controlCircleZoneInfluence,
    Zone.accept => l10n.controlCircleZoneAccept,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    Zone.control => l10n.controlCircleZoneControlHint,
    Zone.influence => l10n.controlCircleZoneInfluenceHint,
    Zone.accept => l10n.controlCircleZoneAcceptHint,
  };
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
                    tooltip: context.l10n.commonRemove,
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
                      label: z.label(context.l10n),
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
    final l10n = context.l10n;
    final (advice, action, onTap) = switch (z) {
      Zone.control => (
        l10n.controlCircleControlAdvice,
        l10n.controlCircleControlAction,
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ProblemSolvingScreen())),
      ),
      Zone.influence => (
        l10n.controlCircleInfluenceAdvice,
        null,
        null,
      ),
      Zone.accept => (
        l10n.controlCircleAcceptAdvice,
        l10n.controlCircleAcceptAction,
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
                  l10n.controlCircleZoneCount(z.label(l10n), items.length),
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
                l10n.cbtBullet(s.text),
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
    final l10n = context.l10n;
    if (items == null) {
      return ToolkitScaffold(
        accent: stressAccent,
        title: l10n.controlCircleTitle,
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    final sorted = items.where((s) => s.zone != null).length;
    return ToolkitScaffold(
      accent: stressAccent,
      title: l10n.controlCircleTitle,
      children: [
        ToolkitSection(
          title: l10n.controlCircleSectionTitle,
          subtitle: l10n.controlCircleSectionBody,
        ),
        TextField(
          controller: _input,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _add(),
          decoration: InputDecoration(
            labelText: l10n.controlCircleInputLabel,
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
          ToolkitSection(title: l10n.controlCircleEffortTitle),
          for (final z in Zone.values)
            _zoneSummary(z, items.where((s) => s.zone == z).toList()),
        ],
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.controlCircleEmpty,
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
