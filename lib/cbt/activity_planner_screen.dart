import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import 'cbt_content.dart';
import '../toolkit/toolkit_ui.dart';

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
          ..showSnackBar(
            SnackBar(content: Text(context.l10n.activityPlannerTooMany)),
          );
        return;
      }
    });
    plan.save();
  }

  void _markDone(String label) {
    final plan = _plan!;
    setState(() {
      plan.done.contains(label)
          ? plan.done.remove(label)
          : plan.done.add(label);
    });
    plan.save();
    if (plan.done.length == plan.picked.length && plan.picked.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.activityPlannerAllDone)),
        );
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
    final l10n = context.l10n;
    if (plan == null) {
      return ToolkitScaffold(
        accent: cbtAccent,
        title: l10n.activityPlannerTitle,
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    final c = context.brand;
    final ideas = _filter == null
        ? activityIdeas
        : activityIdeas.where((a) => a.category == _filter).toList();
    return ToolkitScaffold(
      accent: cbtAccent,
      title: l10n.activityPlannerTitle,
      children: [
        ToolkitSection(
          title: l10n.activityPlannerSectionTitle,
          subtitle: l10n.activityPlannerSectionBody,
        ),
        if (plan.picked.isNotEmpty) ...[
          ToolkitNote(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.activityPlannerTodayProgress(
                    plan.done.length,
                    plan.picked.length,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 6),
                for (final label in plan.picked)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    // A fixed red box carrying its own white tick.
                    activeColor: cbtAccent,
                    checkColor: Colors.white,
                    value: plan.done.contains(label),
                    onChanged: (_) => _markDone(label),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.ink,
                        decoration: plan.done.contains(label)
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    secondary: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: c.textMuted,
                      onPressed: () => _toggle(label),
                      tooltip: l10n.commonRemove,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        ToolkitSection(title: l10n.activityPlannerIdeas),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ToolkitPill(
              label: l10n.activityPlannerAll,
              selected: _filter == null,
              onTap: () => setState(() => _filter = null),
            ),
            for (final category in ActivityCategory.values)
              ToolkitPill(
                label: category.label,
                icon: category.icon,
                selected: _filter == category,
                onTap: () => setState(() => _filter = category),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final idea in ideas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: plan.picked.contains(idea.label) ? c.ink : c.card,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggle(idea.label),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        idea.category.icon,
                        size: 18,
                        color: plan.picked.contains(idea.label)
                            ? c.onInk
                            : c.accent(cbtAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          idea.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: plan.picked.contains(idea.label)
                                ? c.onInk
                                : c.ink,
                          ),
                        ),
                      ),
                      Icon(
                        plan.picked.contains(idea.label)
                            ? Icons.check_rounded
                            : Icons.add_rounded,
                        size: 18,
                        color: plan.picked.contains(idea.label)
                            ? c.onInk
                            : c.textMuted,
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
            labelText: l10n.activityPlannerOwnField,
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
