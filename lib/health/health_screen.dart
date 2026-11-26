import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/auth_ui.dart';
import '../billing/pricing_copy.dart';
import '../brand.dart';
import '../brand_layout.dart';
import '../discover/content_index.dart';
import '../discover/goals.dart';
import '../engagement/next_step.dart';
import '../home/home_ui.dart';
import '../home/mood_repository.dart';
import '../l10n/l10n.dart';
import '../practice/practice_repository.dart';
import 'health_data.dart';
import 'health_service.dart';

/// Apple Health / Health Connect: what's read and saved and why, the
/// consent to it, and — once connected — the week, today's suggestion and
/// the patterns in the person's own data.
///
/// The "before" half is what Apple's and Google's reviewers look for: the
/// purpose of each data type, stated before the system sheet appears, and
/// that the data stays on the phone.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const HealthScreen());

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final _service = HealthService.instance;
  bool _busy = false;
  List<MoodLink>? _links;

  @override
  void initState() {
    super.initState();
    _service.addListener(_changed);
    if (_service.status == HealthStatus.unknown) {
      _service.load();
    } else {
      _service.refresh();
    }
    _loadLinks();
  }

  @override
  void dispose() {
    _service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _loadLinks();
  }

  /// Moods and practice come from the account; health from the phone. They
  /// meet only here, on the phone.
  Future<void> _loadLinks() async {
    if (!_service.connected || _service.history.isEmpty) return;
    try {
      final moods = await MoodRepository().fetchHistory(days: 30);
      final practice = await PracticeRepository().fetchRecent(days: 30);
      final links = moodLinks(
        history: _service.history,
        moods: {
          for (final m in moods) PracticeRepository.dateKey(m.date): m.index + 1,
        },
        practiceDays: {
          for (final s in practice)
            if (s.kind != PracticeKind.sound)
              PracticeRepository.dateKey(s.completedAt),
        },
      );
      if (mounted) setState(() => _links = links);
    } catch (e) {
      debugPrint('Mood links unavailable: ${e.runtimeType}');
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    final ok = await _service.connect();
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.healthConnectFailed(HealthService.platformName),
          ),
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    await _service.disconnect();
    if (!mounted) return;
    setState(() => _links = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.healthDisconnected(HealthService.platformName),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final platform = HealthService.platformName;
    final connected = _service.connected;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kReadableMaxWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              children: [
                const Align(alignment: Alignment.centerLeft, child: BackChip()),
                const SizedBox(height: 20),
                Text(
                  connected
                      ? l10n.healthConnectedTitle
                      : l10n.healthConnectTitle(platform),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                if (connected) ..._connected(context) else ..._consent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Before connecting ──────────────────────────────────────────

  List<Widget> _consent(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final platform = HealthService.platformName;
    return [
      Text(
        l10n.healthIntro,
        style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.55),
      ),
      const SizedBox(height: 24),
      _heading(l10n.healthReadHeading),
      _item(Icons.bedtime_rounded, Pillars.blue, l10n.healthReadSleep,
          l10n.healthReadSleepDetail),
      _item(Icons.directions_walk_rounded, Pillars.yellow, l10n.healthReadSteps,
          l10n.healthReadStepsDetail),
      _item(Icons.favorite_rounded, Pillars.red, l10n.healthReadHeart,
          l10n.healthReadHeartDetail),
      const SizedBox(height: 12),
      _heading(l10n.healthWriteHeading),
      _item(Icons.self_improvement_rounded, Pillars.blue,
          l10n.healthWriteMindful, l10n.healthWriteMindfulDetail),
      const SizedBox(height: 12),
      _panel(
        icon: Icons.lock_rounded,
        title: l10n.healthPrivacyTitle,
        body: l10n.healthPrivacyBody,
      ),
      const SizedBox(height: 24),
      switch (_service.status) {
        HealthStatus.unknown => Center(
          child: CircularProgressIndicator(color: c.ink, strokeWidth: 2.6),
        ),
        HealthStatus.unavailable => Text(
          l10n.healthUnavailable(platform),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textMuted),
        ),
        HealthStatus.needsInstall => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.healthInstallBody,
              style: TextStyle(fontSize: 13.5, color: c.textMuted, height: 1.5),
            ),
            const SizedBox(height: 12),
            AuthSubmitButton(
              label: l10n.healthInstallButton,
              onPressed: _service.installHealthConnect,
            ),
          ],
        ),
        HealthStatus.notConnected || HealthStatus.connected => AuthSubmitButton(
          label: l10n.healthConnectTitle(platform),
          loading: _busy,
          onPressed: _connect,
        ),
      },
      const SizedBox(height: 16),
      Text(
        l10n.healthNotMedical,
        style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.5),
      ),
    ];
  }

  // ── Connected ──────────────────────────────────────────────────

  List<Widget> _connected(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final now = DateTime.now();
    final history = _service.history;
    final week = history.lastDays(now, 7);
    final signals = healthSignals(history, now);
    final step = chooseNextStep(
      now: now,
      premium: isPremiumUser(),
      signals: signals,
      goals: userGoals(),
    );
    final locale = Localizations.localeOf(context).toString();
    String sleep(num minutes) =>
        l10n.healthSleepValue(minutes ~/ 60, (minutes % 60).round());
    final sleeps = [for (final d in week) d.sleepMinutes];
    final steps = [
      for (final d in week.skip(1)) d.steps,
      // Today's steps are still going up: the chart ends with yesterday.
    ];
    final knownSleep = sleeps.whereType<int>();
    final knownSteps = steps.whereType<int>();
    return [
      if (step != null) ...[
        _suggestion(step),
        const SizedBox(height: 20),
      ],
      _heading(l10n.healthWeekSleep),
      _bars(
        values: sleeps,
        days: week,
        color: Pillars.blue,
        footer: knownSleep.isEmpty
            ? l10n.healthNoSleep
            : l10n.healthAverage(
                sleep(knownSleep.reduce((a, b) => a + b) / knownSleep.length),
              ),
      ),
      const SizedBox(height: 20),
      _heading(l10n.healthWeekSteps),
      _bars(
        values: steps,
        days: week.skip(1).toList(),
        color: Pillars.yellow,
        footer: knownSteps.isEmpty
            ? l10n.healthNoSteps
            : l10n.healthAverage(
                l10n.healthStepsValue(
                  NumberFormat.decimalPattern(locale).format(
                    knownSteps.reduce((a, b) => a + b) ~/ knownSteps.length,
                  ),
                ),
              ),
      ),
      const SizedBox(height: 24),
      _heading(l10n.healthMoodLinksHeading),
      PremiumBuilder(builder: (context, premium) => _linksBlock(premium)),
      const SizedBox(height: 24),
      _panel(
        icon: Icons.self_improvement_rounded,
        title: l10n.healthWriteMindful,
        body: _service.canWriteMindful
            ? l10n.healthMindfulOn
            : l10n.healthMindfulUnavailable,
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _service.showSleepOnWidget,
        onChanged: _service.setShowSleepOnWidget,
        title: Text(
          l10n.healthWidgetSleep,
          style: TextStyle(fontSize: 14, color: c.ink),
        ),
      ),
      const SizedBox(height: 8),
      _panel(
        icon: Icons.lock_rounded,
        title: l10n.healthPrivacyTitle,
        body: l10n.healthPrivacyBody,
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: _disconnect,
        child: Text(l10n.healthDisconnect),
      ),
      if (Platform.isIOS) ...[
        const SizedBox(height: 8),
        Text(
          l10n.healthDisconnectIos,
          style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.5),
        ),
      ],
      const SizedBox(height: 16),
      Text(
        l10n.healthNotMedical,
        style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.5),
      ),
    ];
  }

  Widget _suggestion(NextStep step) {
    final c = context.brand;
    final item = step.item;
    return Material(
      color: c.tint(item.accent, 0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openContent(context, item, source: 'health:suggestion'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.line(context.l10n),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: c.accent(item.accent),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.meta(context.l10n),
                      style: TextStyle(fontSize: 12.5, color: c.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(item.icon, color: c.accent(item.accent)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linksBlock(bool premium) {
    final c = context.brand;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    if (!premium) {
      return Material(
        color: c.tint(Pillars.yellow, 0.08),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showUpgradeSheet(
            context,
            title: l10n.healthMoodLinksHeading,
            message: l10n.contentPremiumMessage(introOffer),
            source: 'health:mood_links',
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.moodLinksLocked,
                    style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.45),
                  ),
                ),
                const SizedBox(width: 10),
                const PremiumChip(),
              ],
            ),
          ),
        ),
      );
    }
    final links = _links;
    if (links == null || links.isEmpty) {
      return Text(
        l10n.moodLinksNotYet,
        style: TextStyle(fontSize: 13.5, color: c.textMuted, height: 1.5),
      );
    }
    final f = NumberFormat('0.0', locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              switch (link.kind) {
                MoodLinkKind.sleep => l10n.moodLinkSleep(
                  f.format(link.withAverage),
                  f.format(link.withoutAverage),
                ),
                MoodLinkKind.movement => l10n.moodLinkMovement(
                  f.format(link.withAverage),
                  f.format(link.withoutAverage),
                ),
                MoodLinkKind.practice => l10n.moodLinkPractice(
                  f.format(link.withAverage),
                  f.format(link.withoutAverage),
                ),
              },
              style: TextStyle(fontSize: 14, color: c.ink, height: 1.5),
            ),
          ),
        Text(
          l10n.moodLinkFootnote,
          style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.5),
        ),
      ],
    );
  }

  // ── Pieces ─────────────────────────────────────────────────────

  Widget _heading(String text) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink),
      ),
    );
  }

  Widget _item(IconData icon, Color accent, String title, String detail) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.tint(accent, 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: c.accent(accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required IconData icon,
    required String title,
    required String body,
  }) {
    final c = context.brand;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.tint(Pillars.blue, 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.accent(Pillars.blue)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Seven bars, scaled to the tallest, with the weekday under each.
  Widget _bars({
    required List<int?> values,
    required List<DailyHealth> days,
    required Color color,
    required String footer,
  }) {
    final c = context.brand;
    final locale = Localizations.localeOf(context).toString();
    final known = values.whereType<int>();
    final top = known.isEmpty ? 1 : known.reduce((a, b) => a > b ? a : b);
    final weekday = DateFormat.E(locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: values[i] == null
                              ? 4
                              : 8 + 64 * values[i]! / (top == 0 ? 1 : top),
                          decoration: BoxDecoration(
                            color: values[i] == null
                                ? c.border
                                : c.art(color).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weekday.format(days[i].day),
                          maxLines: 1,
                          style: TextStyle(fontSize: 10.5, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(footer, style: TextStyle(fontSize: 12.5, color: c.textMuted)),
      ],
    );
  }
}
