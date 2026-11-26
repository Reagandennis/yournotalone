import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../discover/content_index.dart';
import '../discover/content_widgets.dart';
import '../discover/goals.dart';
import '../discover/taste_store.dart';
import '../engagement/next_step.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
import 'health_data.dart';
import 'health_screen.dart';
import 'health_service.dart';

/// Home's health card. Before connecting: a small invite, which "Not now"
/// puts away for a month. Once connected: last night, yesterday's steps,
/// and the one suggestion the day's data points to.
class HealthCard extends StatefulWidget {
  const HealthCard({super.key});

  @override
  State<HealthCard> createState() => _HealthCardState();
}

class _HealthCardState extends State<HealthCard> {
  static const _dismissedKey = 'health.invite_dismissed_at';
  static const _inviteAgainAfter = Duration(days: 30);

  final _service = HealthService.instance;
  bool _inviteHidden = true;

  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
    // "Not for me" on the pick, here or elsewhere, changes the pick.
    TasteStore.instance.addListener(_changed);
    _loadDismissed();
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    TasteStore.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = DateTime.tryParse(prefs.getString(_dismissedKey) ?? '');
      final hidden = at != null && DateTime.now().difference(at) < _inviteAgainAfter;
      if (mounted) setState(() => _inviteHidden = hidden);
    } catch (_) {
      if (mounted) setState(() => _inviteHidden = false);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _inviteHidden = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dismissedKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  void _open() => Navigator.of(context).push(HealthScreen.route());

  @override
  Widget build(BuildContext context) {
    switch (_service.status) {
      case HealthStatus.connected:
        return _connected(context);
      case HealthStatus.notConnected || HealthStatus.needsInstall:
        return _inviteHidden ? const SizedBox.shrink() : _invite(context);
      case HealthStatus.unknown || HealthStatus.unavailable:
        return const SizedBox.shrink();
    }
  }

  Widget _invite(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border, width: 1.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 18, color: c.accent(Pillars.red)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.healthInviteTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l10n.healthInviteBody(HealthService.platformName),
              style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.45),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _dismiss, child: Text(l10n.healthInviteLater)),
                TextButton(onPressed: _open, child: Text(l10n.healthInviteConnect)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _connected(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final now = DateTime.now();
    final history = _service.history;
    final today = history.on(now);
    final yesterday = history.on(DateTime(now.year, now.month, now.day - 1));
    final step = chooseNextStep(
      now: now,
      premium: isPremiumUser(),
      signals: healthSignals(history, now),
      goals: userGoals(),
    );
    final locale = Localizations.localeOf(context).toString();
    final sleep = today?.sleepMinutes;
    final steps = yesterday?.steps;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border, width: 1.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.healthCardTitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: c.accent(Pillars.blue),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _stat(
                        Icons.bedtime_rounded,
                        l10n.healthLastNight,
                        sleep == null
                            ? l10n.healthNoSleep
                            : l10n.healthSleepValue(sleep ~/ 60, sleep % 60),
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        Icons.directions_walk_rounded,
                        l10n.healthYesterday,
                        steps == null
                            ? l10n.healthNoSteps
                            : l10n.healthStepsValue(
                                NumberFormat.decimalPattern(locale).format(steps),
                              ),
                      ),
                    ),
                  ],
                ),
                if (step != null) ...[
                  const SizedBox(height: 14),
                  Divider(height: 1, color: c.border),
                  const SizedBox(height: 12),
                  Text(
                    step.line(l10n),
                    style: TextStyle(fontSize: 12.5, color: c.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(step.item.icon, size: 18, color: c.accent(step.item.accent)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => openContent(
                          context,
                          step.item,
                          source: 'home:health',
                        ),
                        child: Text(l10n.healthOpen),
                      ),
                    ],
                  ),
                  // A course day is the course's, not a guess to correct.
                  if (step.reason != NextStepReason.course)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: NotForMeButton(
                        item: step.item,
                        source: 'home:health',
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    final c = context.brand;
    return Row(
      children: [
        Icon(icon, size: 18, color: c.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11.5, color: c.textMuted)),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
