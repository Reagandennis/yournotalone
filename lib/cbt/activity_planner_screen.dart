import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import 'cbt_content.dart';
import 'cbt_ui.dart';

/// Today's plan: which activities were picked and which are done. Kept on
/// the phone only, one key per day, so an old plan never nags.
class ActivityPlan {
  ActivityPlan(this.day, this.picked, this.done);

  final String day;
  final List<String> picked;
  final Set<String> done;

  static String today([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static String _key(String day) => 'cbt.plan.$day';

  static Future<ActivityPlan> load([DateTime? now]) async {
    final day = today(now);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(day));
    if (raw == null) return ActivityPlan(day, [], {});
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return ActivityPlan(
      day,
      [...(map['picked'] as List).cast<String>()],
      {...(map['done'] as List).cast<String>()},
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(day),
      jsonEncode({'picked': picked, 'done': done.toList()}),
    );
  }
}

/// Behavioural activation, kept small: pick up to three doable things for
/// today, one from anywhere that gives a lift, and tick them off.
class ActivityPlannerScreen extends StatefulWidget {
  const ActivityPlannerScreen({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  State<ActivityPlannerScreen> createState() => _ActivityPlannerScreenState();
}

class _ActivityPlannerScreenState extends State<ActivityPlannerScreen> {
  static const _max = 3;
  ActivityPlan? _plan;
  ActivityCategory? _filter;
  final _custom = TextEditingController();

  @override
  void initState() {
    super.initState();
    ActivityPlan.load(widget.clock?.call()).then((plan) {
      if (mounted) setState(() => _plan = plan);
    });
  }

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _toggle(String label) {
    final plan = _plan!;
    setState(() {
      if (plan.picked.contains(label)) {
        plan.picked.remove(label);
        plan.done.remove(label);
      } else if (plan.picked.length < _max) {
        plan.picked.add(label);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Three is plenty for one day. Swap one out if '
                'you\'d rather.'),
          ));
        return;
      }
    });
    plan.save();
  }

  void _markDone(String label) {
    final plan = _plan!;
    setState(() {
      plan.done.contains(label) ? plan.done.remove(label) : plan.done.add(label);
    });
    plan.save();
    if (plan.done.length == plan.picked.length && plan.picked.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('That\'s today\'s plan done. Notice how you feel now '
              'compared with before.'),
        ));
    }
  }

  void _addCustom() {
    final text = _custom.text.trim();
    if (text.isEmpty) return;
    _custom.clear();
    _toggle(text);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (plan == null) {
      return const CbtScaffold(
        title: 'One small thing',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final ideas = _filter == null
        ? activityIdeas
        : activityIdeas.where((a) => a.category == _filter).toList();
    return CbtScaffold(
      title: 'One small thing',
      children: [
        const CbtSection(
          title: 'Do first, feel later',
          subtitle: 'When mood is low, motivation doesn\'t come before '
              'action — it comes after. Pick up to three small things for '
              'today. Small enough that you\'d do them on a bad day.',
        ),
        if (plan.picked.isNotEmpty) ...[
          CbtNote(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today · ${plan.done.length} of ${plan.picked.length} done',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 6),
                for (final label in plan.picked)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: cbtAccent,
                    value: plan.done.contains(label),
                    onChanged: (_) => _markDone(label),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: Brand.ink,
                        decoration: plan.done.contains(label)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    secondary: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: Brand.textMuted,
                      onPressed: () => _toggle(label),
                      tooltip: 'Remove',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const CbtSection(title: 'Ideas'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CbtPill(
              label: 'All',
              selected: _filter == null,
              onTap: () => setState(() => _filter = null),
            ),
            for (final c in ActivityCategory.values)
              CbtPill(
                label: c.label,
                icon: c.icon,
                selected: _filter == c,
                onTap: () => setState(() => _filter = c),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final idea in ideas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: plan.picked.contains(idea.label) ? Brand.ink : cbtCardColor,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggle(idea.label),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  child: Row(
                    children: [
                      Icon(
                        idea.category.icon,
                        size: 18,
                        color: plan.picked.contains(idea.label)
                            ? Colors.white
                            : cbtAccent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          idea.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: plan.picked.contains(idea.label)
                                ? Colors.white
                                : Brand.ink,
                          ),
                        ),
                      ),
                      Icon(
                        plan.picked.contains(idea.label)
                            ? Icons.check_rounded
                            : Icons.add_rounded,
                        size: 18,
                        color: plan.picked.contains(idea.label)
                            ? Colors.white
                            : Brand.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _custom,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _addCustom(),
          decoration: InputDecoration(
            labelText: 'Or something of your own',
            counterText: '',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: _addCustom,
            ),
          ),
        ),
      ],
    );
  }
}
