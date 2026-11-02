import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../reminders/reminders_screen.dart';
import '../toolkit/toolkit_ui.dart';
import 'sleep_content.dart';

const _bedtimeKey = 'sleep.bedtime';

/// Tonight's wind-down: the bedtime it counts back from, and which steps
/// are done. Kept on the phone; a new night starts a fresh checklist.
class WindDownPlan {
  WindDownPlan(this.bedtime, this.day, this.done);

  TimeOfDay bedtime;
  final String day;
  final Set<String> done;

  static String today([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static Future<WindDownPlan> load([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final bed = prefs.getString(_bedtimeKey) ?? '22:30';
    final parts = bed.split(':');
    final day = today(now);
    final raw = prefs.getString('sleep.winddown.$day');
    return WindDownPlan(
      TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      day,
      raw == null ? {} : {...(jsonDecode(raw) as List).cast<String>()},
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _bedtimeKey,
      '${bedtime.hour.toString().padLeft(2, '0')}:${bedtime.minute.toString().padLeft(2, '0')}',
    );
    await prefs.setString('sleep.winddown.$day', jsonEncode(done.toList()));
  }

  /// The clock time [minutesBefore] bedtime.
  TimeOfDay at(int minutesBefore) {
    final total =
        (bedtime.hour * 60 + bedtime.minute - minutesBefore + 1440) % 1440;
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }
}

/// An hour of small steps counted back from a bedtime you choose, ticked
/// off as the evening goes. The wind-down reminder lives with the other
/// reminders, one tap away.
class WindDownScreen extends StatefulWidget {
  const WindDownScreen({super.key, this.clock});

  final DateTime Function()? clock;

  @override
  State<WindDownScreen> createState() => _WindDownScreenState();
}

class _WindDownScreenState extends State<WindDownScreen> {
  WindDownPlan? _plan;

  @override
  void initState() {
    super.initState();
    WindDownPlan.load(widget.clock?.call()).then((p) {
      if (mounted) setState(() => _plan = p);
    });
  }

  Future<void> _pickBedtime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _plan!.bedtime,
      helpText: context.l10n.windDownPickerTitle,
    );
    if (picked == null || !mounted) return;
    setState(() => _plan!.bedtime = picked);
    await _plan!.save();
  }

  void _toggle(String id) {
    final plan = _plan!;
    setState(
      () => plan.done.contains(id) ? plan.done.remove(id) : plan.done.add(id),
    );
    plan.save();
    if (plan.done.length == windDownSteps.length) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.windDownAllDone)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final plan = _plan;
    if (plan == null) {
      return ToolkitScaffold(
        accent: sleepAccent,
        title: l10n.windDownTitle,
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    final c = context.brand;
    final bed = plan.bedtime.format(context);
    return ToolkitScaffold(
      accent: sleepAccent,
      title: l10n.windDownTitle,
      children: [
        ToolkitSection(
          title: l10n.windDownIntroTitle,
          subtitle: l10n.windDownIntroHint,
        ),
        ToolkitNote(
          tint: c.tint(sleepAccent, 0.08),
          child: Row(
            children: [
              Icon(Icons.bedtime_rounded, color: c.accent(sleepAccent)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.windDownLightsOutAt(bed),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      l10n.windDownLightsOutHint,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _pickBedtime,
                child: Text(l10n.commonChange),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final step in windDownSteps)
          _StepTile(
            step: step,
            time: plan.at(step.minutesBefore).format(context),
            done: plan.done.contains(step.id),
            onTap: () => _toggle(step.id),
          ),
        const SizedBox(height: 12),
        ToolkitNote(
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: c.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.windDownReminderNote,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.ink,
                    height: 1.45,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RemindersScreen()),
                ),
                child: Text(l10n.windDownReminderButton),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.time,
    required this.done,
    required this.onTap,
  });

  final WindDownStep step;
  final String time;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final mutedOnInk = c.onInk.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: done ? c.ink : c.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: done
                        ? c.onInk.withValues(alpha: 0.24)
                        : c.tint(sleepAccent, 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : step.icon,
                    size: 20,
                    color: done ? c.onInk : c.accent(sleepAccent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.windDownStepTime(time, step.minutesBefore),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: done ? mutedOnInk : c.accent(sleepAccent),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: done ? c.onInk : c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.detail,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: done ? mutedOnInk : c.textMuted,
                          height: 1.4,
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
    );
  }
}
