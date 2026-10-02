import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../toolkit/toolkit_ui.dart';
import 'stress_content.dart';

/// The person's own map of what empties and what fills them, and today's
/// one chosen refill. Kept on the phone.
class RechargeList {
  RechargeList(this.drains, this.refuels, this.pick, this.pickDay);

  final List<String> drains;
  final List<String> refuels;
  String? pick;
  String? pickDay;

  static String today([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static Future<RechargeList> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('stress.recharge');
    if (raw == null) return RechargeList([], [], null, null);
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return RechargeList(
      [...(m['drains'] as List).cast<String>()],
      [...(m['refuels'] as List).cast<String>()],
      m['pick'] as String?,
      m['pickDay'] as String?,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'stress.recharge',
      jsonEncode({
        'drains': drains,
        'refuels': refuels,
        'pick': pick,
        'pickDay': pickDay,
      }),
    );
  }

  /// Today's pick, or null if the last one was another day.
  String? pickFor(String day) => pickDay == day ? pick : null;
}

/// Two honest lists — what drains you, what refills you — and one refill
/// chosen for today. Recovery has to be scheduled; it doesn't just happen.
class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen> {
  RechargeList? _list;
  final _drain = TextEditingController();
  final _refuel = TextEditingController();

  String get _today => RechargeList.today(widget.clock?.call());

  @override
  void initState() {
    super.initState();
    RechargeList.load().then((l) {
      if (mounted) setState(() => _list = l);
    });
  }

  @override
  void dispose() {
    _drain.dispose();
    _refuel.dispose();
    super.dispose();
  }

  void _add(List<String> to, TextEditingController c) {
    final text = c.text.trim();
    if (text.isEmpty || to.contains(text)) return;
    setState(() {
      to.add(text);
      c.clear();
    });
    _list!.save();
  }

  void _remove(List<String> from, String item) {
    setState(() {
      from.remove(item);
      if (_list!.pick == item) _list!.pick = null;
    });
    _list!.save();
  }

  void _pick(String item) {
    setState(() {
      final l = _list!;
      l.pick = l.pickFor(_today) == item ? null : item;
      l.pickDay = _today;
    });
    _list!.save();
  }

  Widget _chips(List<String> items, {required bool refuel}) {
    final c = context.brand;
    final pick = _list!.pickFor(_today);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          InputChip(
            label: Text(item),
            selected: refuel && pick == item,
            // Today's pick is solid yellow, so it keeps dark text in both
            // modes.
            selectedColor: stressAccent,
            checkmarkColor: BrandColors.light.ink,
            backgroundColor: c.card,
            side: BorderSide.none,
            labelStyle: TextStyle(
              fontSize: 13,
              color: refuel && pick == item ? BrandColors.light.ink : c.ink,
            ),
            onSelected: refuel ? (_) => _pick(item) : null,
            onDeleted: () => _remove(items, item),
            deleteIconColor: refuel && pick == item
                ? BrandColors.light.textMuted
                : c.textMuted,
          ),
      ],
    );
  }

  Widget _input(TextEditingController c, String label, List<String> to) {
    return TextField(
      controller: c,
      maxLength: 60,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => _add(to, c),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        suffixIcon: IconButton(
          icon: const Icon(Icons.add_rounded),
          onPressed: () => _add(to, c),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    if (list == null) {
      return const ToolkitScaffold(
        accent: stressAccent,
        title: 'Recharge list',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final c = context.brand;
    final pick = list.pickFor(_today);
    return ToolkitScaffold(
      accent: stressAccent,
      title: 'Recharge list',
      children: [
        const ToolkitSection(
          title: 'Know your tank',
          subtitle:
              'Stress is a budget: things that take from it and things '
              'that pay in. Most people can name the drains instantly and go '
              'quiet on the refills. Write both. Then choose one refill for '
              'today — and treat it as an appointment.',
        ),
        if (pick != null) ...[
          ToolkitNote(
            tint: c.tint(stressAccent, 0.14),
            child: Row(
              children: [
                Icon(
                  Icons.battery_charging_full_rounded,
                  color: c.ink,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Today: $pick',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        const ToolkitSection(title: 'What drains me'),
        _chips(list.drains, refuel: false),
        const SizedBox(height: 10),
        _input(_drain, 'Add a drain', list.drains),
        const SizedBox(height: 22),
        const ToolkitSection(
          title: 'What refills me',
          subtitle: 'Tap one to make it today\'s.',
        ),
        _chips(list.refuels, refuel: true),
        const SizedBox(height: 10),
        _input(_refuel, 'Add a refill', list.refuels),
        const SizedBox(height: 18),
        Text(
          'Stuck for refills? Borrow one:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final idea in rechargeIdeas)
              if (!list.refuels.contains(idea.label))
                ActionChip(
                  avatar: Icon(idea.icon, size: 16, color: c.ink),
                  label: Text(idea.label),
                  labelStyle: TextStyle(fontSize: 12.5, color: c.ink),
                  backgroundColor: c.card,
                  side: BorderSide(color: c.border),
                  onPressed: () {
                    setState(() => list.refuels.add(idea.label));
                    list.save();
                  },
                ),
          ],
        ),
      ],
    );
  }
}
