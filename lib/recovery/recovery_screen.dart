import 'package:flutter/material.dart';
import '../billing/pricing_copy.dart';

import '../auth/auth_ui.dart';
import '../billing/purchases_service.dart';
import '../brand.dart';
import '../content/content_catalog.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
import '../meditation/meditation_catalog.dart';
import '../meditation/meditation_screen.dart';
import '../support/crisis_screen.dart';
import '../toolkit/guided_exercise.dart';
import 'halt_screen.dart';
import 'insights_screen.dart';
import 'milestones_screen.dart';
import 'recovery_repository.dart';
import 'tape_forward_screen.dart';

/// The urge-surfing session: free for everyone — it's the tool for the
/// hardest minutes, so it stays outside the paywall.
const urgeSurfMeditation = Meditation(
  'Urge surfing',
  'Urges are waves — ride this one until it breaks.',
  8,
  Icons.surfing_rounded,
  Pillars.blue,
  premium: false,
  prompts: [
    (0.0, 'You\'re here — that\'s the strongest move you could make.'),
    (0.05, 'An urge is a wave. It rises, it peaks, and it always falls.'),
    (0.12, 'Don\'t fight it. Just watch it, like weather passing through.'),
    (0.2, 'Where do you feel it in your body? Just notice, without acting.'),
    (0.3, 'Breathe out slowly — longer out than in.'),
    (0.42, 'You don\'t have to act. You only have to wait.'),
    (0.55, 'It\'s already losing strength, even if slowly.'),
    (0.68, 'Think of tomorrow-you, grateful that you held on today.'),
    (0.8, 'Still here. Still riding. The wave is passing.'),
    (0.92, 'You surfed it. Every urge you outlast makes the next one smaller.'),
  ],
);

/// Saved as is in `craving_logs.trigger_kind` — never change these; they
/// are named on screen through [recoveryTriggerLabel].
const _triggerKinds = recoveryTriggerKinds;

/// Recovery hub: SOS urge surfing, commitments with streaks & pledges,
/// and the craving trigger tracker.
class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _repo = RecoveryRepository();
  List<RecoveryHabit>? _habits;
  List<CravingLog>? _cravings;
  bool _error = false;

  bool get _premium => isPremiumUser();

  @override
  void initState() {
    super.initState();
    if (_premium) _load();
    // Upgrading from inside this screen used to leave it spinning forever:
    // the data is only fetched for premium users, and nothing re-ran the
    // fetch when the entitlement arrived.
    PurchasesService.instance.isPro.addListener(_onEntitlementChanged);
  }

  @override
  void dispose() {
    PurchasesService.instance.isPro.removeListener(_onEntitlementChanged);
    super.dispose();
  }

  void _onEntitlementChanged() {
    if (!mounted) return;
    if (_premium && _habits == null) {
      _load();
    } else {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final habits = await _repo.fetchHabits();
      final cravings = await _repo.fetchRecentCravings();
      if (mounted) {
        setState(() {
          _habits = habits;
          _cravings = cravings;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _showLockedSheet() {
    showUpgradeSheet(
      context,
      source: 'sheet:recovery',
      title: context.l10n.recoveryPremiumTitle,
      message: context.l10n.recoveryPremiumMessage(introOffer),
    );
  }

  // ── Commitments ────────────────────────────────────────────────

  Future<void> _addHabitSheet() async {
    final c = context.brand;
    final l10n = context.l10n;
    final controller = TextEditingController();
    var dayOne = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            26,
            28,
            30 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.recoveryAddHabitTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.recoveryAddHabitHint,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.recoveryCountingFrom,
                style: TextStyle(fontSize: 13, color: c.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final (label, date) in [
                    (l10n.recoveryToday, DateTime.now()),
                    (
                      l10n.recoveryYesterday,
                      DateTime.now().subtract(const Duration(days: 1))
                    ),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: dayOne.day == date.day &&
                          dayOne.month == date.month,
                      onSelected: (_) => setSheetState(() => dayOne = date),
                    ),
                  ActionChip(
                    label: Text(l10n.recoveryPickADate),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: sheetContext,
                        initialDate: dayOne,
                        firstDate:
                            DateTime.now().subtract(const Duration(days: 3650)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSheetState(() => dayOne = picked);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(sheetContext).pop();
                  try {
                    await _repo.addHabit(name, dayOne);
                    _load();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
            content: Text(errorMessage(e, context.l10n.recoverySaveFailed)),
                        ),
                      );
                    }
                  }
                },
                child: Text(l10n.recoveryStartCounting),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pledge(RecoveryHabit habit) async {
    try {
      await _repo.pledgeToday(habit.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.recoveryPledgedSnack(
                context.l10n.midSentence(habit.name),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(e, context.l10n.recoverySaveFailed)),
          ),
        );
      }
    }
  }

  Future<void> _confirmReset(RecoveryHabit habit) async {
    final best = habit.bestStreakDays > habit.daysIn
        ? habit.bestStreakDays
        : habit.daysIn;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.recoveryResetTitle),
        content: Text(context.l10n.recoveryResetBody(best)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.recoveryResetConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.resetDayOne(habit);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(e, context.l10n.recoverySaveFailed)),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(RecoveryHabit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.recoveryRemoveTitle(habit.name)),
        content: Text(context.l10n.recoveryRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.brand.red),
            child: Text(context.l10n.commonRemove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteHabit(habit.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(e, context.l10n.recoveryDeleteFailed)),
          ),
        );
      }
    }
  }

  Widget _habitCard(RecoveryHabit habit) {
    final c = context.brand;
    final l10n = context.l10n;
    final next = habit.nextMilestoneIn(l10n);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
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
              Expanded(
                child: Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              Text(
                l10n.recoveryDayNumber(habit.daysIn),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.blue,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded,
                    size: 20, color: c.textMuted),
                onSelected: (value) => value == 'reset'
                    ? _confirmReset(habit)
                    : _confirmDelete(habit),
                itemBuilder: (context) => [
                  PopupMenuItem(
                      value: 'reset', child: Text(l10n.recoveryResetDayOne)),
                  PopupMenuItem(value: 'remove', child: Text(l10n.commonRemove)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: habit.milestoneProgress,
                    minHeight: 5,
                    backgroundColor: c.border,
                    color: c.blue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  next == null
                      ? l10n.recoveryPastEveryMilestone
                      : habit.bestStreakDays > 0
                          ? l10n.recoveryNextMilestoneWithBest(
                              next.$2,
                              next.$1 - habit.daysIn,
                              habit.bestStreakDays,
                            )
                          : l10n.recoveryNextMilestone(
                              next.$2,
                              next.$1 - habit.daysIn,
                            ),
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          habit.pledgedToday
              ? Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: c.blue),
                    const SizedBox(width: 6),
                    Text(
                      l10n.recoveryPledgedForToday,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.blue,
                      ),
                    ),
                  ],
                )
              : OutlinedButton(
                  onPressed: () => _pledge(habit),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.ink,
                    side: BorderSide(color: c.ink, width: 1.3),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l10n.recoveryPledgeButton),
                ),
        ],
      ),
    );
  }

  // ── Trigger tracker ────────────────────────────────────────────

  Future<void> _logCravingSheet() async {
    var intensity = 3;
    String trigger = _triggerKinds.first;
    final note = TextEditingController();
    final c = context.brand;
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            28,
            26,
            28,
            30 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.recoveryLogCravingTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.recoveryLogCravingSubtitle,
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.recoveryLogCravingStrength,
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => setSheetState(() => intensity = i),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= intensity
                                ? Color.lerp(
                                    Pillars.yellow, Pillars.red, (i - 1) / 4)
                                : c.tint(Pillars.black, 0.06),
                          ),
                          child: Center(
                            child: Text(
                              '$i',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: i <= intensity
                                    ? Colors.white
                                    : c.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.recoveryLogCravingTrigger,
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in _triggerKinds)
                      ChoiceChip(
                        label: Text(recoveryTriggerLabel(l10n, kind)),
                        selected: trigger == kind,
                        onSelected: (_) =>
                            setSheetState(() => trigger = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.recoveryLogCravingNote,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    try {
                      await _repo.logCraving(
                        intensity: intensity,
                        trigger: trigger,
                        note: note.text.trim(),
                      );
                      _load();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.recoveryCravingLogged),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
            content: Text(errorMessage(e, context.l10n.recoverySaveFailed)),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? get _topTrigger {
    final cravings = _cravings;
    if (cravings == null || cravings.length < 3) return null;
    final counts = <String, int>{};
    for (final c in cravings) {
      counts[c.trigger] = (counts[c.trigger] ?? 0) + 1;
    }
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return top.value > 1 ? top.key : null;
  }

  String _relativeTime(DateTime time) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return l10n.recoveryMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.recoveryHoursAgo(diff.inHours);
    if (diff.inDays == 1) return l10n.recoveryYesterdayLower;
    return l10n.recoveryDaysAgo(diff.inDays);
  }

  Widget _cravingRow(CravingLog log) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                c.art(Pillars.yellow),
                c.art(Pillars.red),
                (log.intensity - 1) / 4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recoveryTriggerLabel(context.l10n, log.trigger),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                if (log.note?.isNotEmpty == true)
                  Text(
                    log.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _relativeTime(log.createdAt),
            style: TextStyle(fontSize: 11.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Shared pieces ──────────────────────────────────────────────

  /// Entry point to one of the tools, gated for free users.
  Widget _toolCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String detail,
    required WidgetBuilder open,
    bool premium = true,
  }) {
    final c = context.brand;
    final locked = premium && !_premium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: locked ? c.tint(Pillars.black, 0.04) : c.tint(accent, 0.06),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: locked
              ? _showLockedSheet
              : () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: open)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.chip,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 21, color: locked ? c.textMuted : c.accent(accent)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (locked)
                  const PremiumChip()
                else
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: c.accent(accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockedCard(String text) {
    final c = context.brand;
    return Material(
      color: c.tint(Pillars.black, 0.04),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _showLockedSheet,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lock_rounded, size: 20, color: c.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.textMuted,
                    height: 1.45,
                  ),
                ),
              ),
              const PremiumChip(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final habits = _habits;
    final cravings = _cravings;
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
                Text(
                  l10n.recoveryTitle,
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
                Text(
                  l10n.recoverySubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                // SOS — free for everyone.
                Material(
                  color: c.tint(Pillars.red, 0.08),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MeditationScreen(
                          meditation: urgeSurfMeditation,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.chip,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.surfing_rounded,
                              size: 22,
                              color: c.red,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.recoveryCravingNowTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: c.ink,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  l10n.recoveryCravingNowBody,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: c.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                SectionHeader(title: l10n.recoveryInTheMoment),
                const SizedBox(height: 10),
                _toolCard(
                  icon: Icons.psychology_alt_rounded,
                  accent: Pillars.yellow,
                  title: l10n.recoveryHaltCardTitle,
                  detail: l10n.recoveryHaltCardDetail,
                  open: (_) => const HaltScreen(),
                ),
                _toolCard(
                  icon: Icons.movie_filter_rounded,
                  accent: Pillars.red,
                  title: l10n.recoveryTapeCardTitle,
                  detail: l10n.recoveryTapeCardDetail,
                  open: (_) => const TapeForwardScreen(),
                ),
                // Exercises added in the content admin.
                for (final g in ContentCatalog.instance.guidedRecovery)
                  _toolCard(
                    icon: g.icon,
                    accent: g.accent,
                    title: g.title,
                    detail: g.blurb,
                    premium: g.premium,
                    open: (_) => GuidedExerciseScreen(exercise: g),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SectionHeader(title: l10n.recoveryMyCommitments),
                    ),
                    if (_premium)
                      TextButton(
                        onPressed: _addHabitSheet,
                        child: Text(l10n.recoveryAddButton),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_premium)
                  _lockedCard(l10n.recoveryCommitmentsLocked)
                else if (_error)
                  Column(
                    children: [
                      Text(
                        l10n.recoveryLoadError,
                        style:
                            TextStyle(fontSize: 13.5, color: c.textMuted),
                      ),
                      TextButton(
                          onPressed: _load, child: Text(l10n.commonTryAgain)),
                    ],
                  )
                else if (habits == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: c.ink,
                        strokeWidth: 2.6,
                      ),
                    ),
                  )
                else if (habits.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.recoveryCommitmentsEmpty,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.textMuted,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  for (final habit in habits) _habitCard(habit),
                const SizedBox(height: 4),
                _toolCard(
                  icon: Icons.emoji_events_rounded,
                  accent: Pillars.blue,
                  title: l10n.recoveryMilestonesCardTitle,
                  detail: l10n.recoveryMilestonesCardDetail,
                  open: (_) => const MilestonesScreen(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SectionHeader(title: l10n.recoveryTriggerTracker),
                    ),
                    if (_premium)
                      TextButton(
                        onPressed: _logCravingSheet,
                        child: Text(l10n.recoveryLogButton),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_premium)
                  _lockedCard(l10n.recoveryTrackerLocked)
                else if (cravings != null) ...[
                  if (_topTrigger != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: c.tint(Pillars.yellow, 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.insights_rounded,
                              size: 18, color: c.ink),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.recoveryTopTrigger(
                                l10n.midSentence(
                                  recoveryTriggerLabel(l10n, _topTrigger!),
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.ink,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (cravings.isEmpty)
                    Text(
                      l10n.recoveryCravingsEmpty,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: c.textMuted,
                        height: 1.5,
                      ),
                    )
                  else
                    for (final log in cravings) _cravingRow(log),
                ],
                const SizedBox(height: 16),
                _toolCard(
                  icon: Icons.query_stats_rounded,
                  accent: Pillars.black,
                  title: l10n.recoveryInsightsCardTitle,
                  detail: l10n.recoveryInsightsCardDetail,
                  open: (_) => const TriggerInsightsScreen(),
                ),
                const SizedBox(height: 16),
                CrisisFooter(
                  textAlign: TextAlign.left,
                  trailing: l10n.recoveryCrisisFooterTrailing,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
