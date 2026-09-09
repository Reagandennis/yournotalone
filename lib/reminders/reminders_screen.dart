import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import 'reminders_service.dart';

/// Settings for the four daily reminders: toggle each on/off and pick
/// its time.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _service = RemindersService.instance;
  final Map<ReminderKind, bool> _enabled = {};
  final Map<ReminderKind, TimeOfDay> _times = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final kind in ReminderKind.values) {
      _enabled[kind] = await _service.isEnabled(kind);
      _times[kind] = await _service.timeOf(kind);
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _toggle(ReminderKind kind, bool on) async {
    try {
      if (on) {
        final granted = await _service.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications are blocked for this app — you '
                    'can allow them in your phone\'s settings.'),
              ),
            );
          }
          return;
        }
        await _service.enable(kind, _times[kind]!);
      } else {
        await _service.disable(kind);
      }
      if (mounted) setState(() => _enabled[kind] = on);
    } catch (e) {
      debugPrint('Reminder toggle failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t set the reminder — fully restart the '
                'app and try again.'),
          ),
        );
      }
    }
  }

  Future<void> _pickTime(ReminderKind kind) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[kind]!,
    );
    if (picked == null) return;
    setState(() => _times[kind] = picked);
    if (_enabled[kind] == true) {
      try {
        await _service.enable(kind, picked); // reschedule at the new time
      } catch (e) {
        debugPrint('Reminder reschedule failed: $e');
      }
    }
  }

  Widget _reminderCard(ReminderKind kind) {
    final on = _enabled[kind] ?? false;
    final time = _times[kind] ?? kind.defaultTime;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border.all(color: Brand.border, width: 1.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kind.accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(kind.icon, size: 21, color: kind.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kind.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Brand.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _pickTime(kind),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: on
                          ? kind.accent.withValues(alpha: 0.10)
                          : const Color(0x0A191919),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: on ? kind.accent : Brand.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            time.format(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: on ? kind.accent : Brand.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            activeTrackColor: Brand.ink,
            onChanged: (value) => _toggle(kind, value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BackChip(),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Reminders',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                const Text(
                  'Gentle daily nudges, only if you want them — tap a time '
                  'to change it.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Brand.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                if (!_loaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Brand.ink,
                        strokeWidth: 2.6,
                      ),
                    ),
                  )
                else
                  for (final kind in ReminderKind.values) _reminderCard(kind),
                const SizedBox(height: 8),
                const Text(
                  'Reminders are scheduled on this device and arrive even '
                  'when the app is closed. Times may shift a few minutes to '
                  'save battery.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Brand.textMuted,
                    height: 1.5,
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
