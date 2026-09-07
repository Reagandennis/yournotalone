import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../billing/purchases_service.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../meditation/meditation_catalog.dart';
import '../meditation/meditation_screen.dart';
import '../support/crisis_screen.dart';
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
  Brand.blue,
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

const _triggerKinds = [
  'Stress',
  'Boredom',
  'Loneliness',
  'Social pressure',
  'Tiredness',
  'Habit',
  'Other',
];

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
      title: 'Recovery tracking is part of Premium',
      message: 'Urge surfing is free for everyone, always. Premium adds '
          'commitment streaks, daily pledges, and the trigger tracker — '
          'and your first month is 80% off.',
    );
  }

  // ── Commitments ────────────────────────────────────────────────

  Future<void> _addHabitSheet() async {
    final controller = TextEditingController();
    var dayOne = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
              const Text(
                'What are you leaving behind?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Brand.ink,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'e.g. Alcohol, smoking, gambling…',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Counting from',
                style: TextStyle(fontSize: 13, color: Brand.textMuted),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final (label, date) in [
                    ('Today', DateTime.now()),
                    (
                      'Yesterday',
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
                    label: const Text('Pick a date'),
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
            content: Text(errorMessage(e, 'Couldn\'t save — check your connection.')),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Start counting'),
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
            content: Text('Pledged: today, not ${habit.name.toLowerCase()}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage(e, 'Couldn\'t save — check your connection.')),
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
        title: const Text('Starting again?'),
        content: Text(
          'Slips happen — they don\'t erase what you learned. Your best '
          'streak ($best days) stays on record, and day one starts now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset to day one'),
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
            content: Text(errorMessage(e, 'Couldn\'t save — check your connection.')),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(RecoveryHabit habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "${habit.name}"?'),
        content: const Text('Its streak and pledges will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Brand.red),
            child: const Text('Remove'),
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
            content: Text(errorMessage(e, 'Couldn\'t delete — check your connection.')),
          ),
        );
      }
    }
  }

  Widget _habitCard(RecoveryHabit habit) {
    final next = habit.nextMilestone;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
      decoration: BoxDecoration(
        border: Border.all(color: Brand.border, width: 1.2),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
              ),
              Text(
                'Day ${habit.daysIn}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Brand.blue,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 20, color: Brand.textMuted),
                onSelected: (value) => value == 'reset'
                    ? _confirmReset(habit)
                    : _confirmDelete(habit),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'reset', child: Text('Reset day one')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
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
                    backgroundColor: Brand.border,
                    color: Brand.blue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  next == null
                      ? 'Past every milestone — extraordinary.'
                      : 'Next milestone: ${next.$2} '
                          '(${next.$1 - habit.daysIn} day'
                          '${next.$1 - habit.daysIn == 1 ? '' : 's'} to go)'
                          '${habit.bestStreakDays > 0 ? ' · best ${habit.bestStreakDays}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Brand.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          habit.pledgedToday
              ? const Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: Brand.blue),
                    SizedBox(width: 6),
                    Text(
                      'Pledged for today',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Brand.blue,
                      ),
                    ),
                  ],
                )
              : OutlinedButton(
                  onPressed: () => _pledge(habit),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Brand.ink,
                    side: const BorderSide(color: Brand.ink, width: 1.3),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('I\'m in for today'),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                const Text(
                  'Log a craving',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Noticing is progress — patterns lose power once you '
                  'can see them.',
                  style: TextStyle(fontSize: 13, color: Brand.textMuted),
                ),
                const SizedBox(height: 18),
                const Text(
                  'How strong was it?',
                  style: TextStyle(fontSize: 13, color: Brand.textMuted),
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
                                    Brand.yellow, Brand.red, (i - 1) / 4)
                                : Brand.border.withValues(alpha: 0.5),
                          ),
                          child: Center(
                            child: Text(
                              '$i',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: i <= intensity
                                    ? Colors.white
                                    : Brand.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'What set it off?',
                  style: TextStyle(fontSize: 13, color: Brand.textMuted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in _triggerKinds)
                      ChoiceChip(
                        label: Text(kind),
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
                  decoration: const InputDecoration(
                    labelText: 'Anything else? (optional)',
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
                          const SnackBar(
                            content: Text(
                                'Logged. You rode it out — that counts.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
            content: Text(errorMessage(e, 'Couldn\'t save — check your connection.')),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
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
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }

  Widget _cravingRow(CravingLog log) {
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
              color:
                  Color.lerp(Brand.yellow, Brand.red, (log.intensity - 1) / 4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.trigger,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
                if (log.note?.isNotEmpty == true)
                  Text(
                    log.note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Brand.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _relativeTime(log.createdAt),
            style: const TextStyle(fontSize: 11.5, color: Brand.textMuted),
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
  }) {
    final locked = !_premium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: locked ? const Color(0x0A191919) : accent.withValues(alpha: 0.06),
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
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 21, color: locked ? Brand.textMuted : accent),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Brand.textMuted,
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
                      size: 14, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockedCard(String text) {
    return Material(
      color: const Color(0x0A191919),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _showLockedSheet,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, size: 20, color: Brand.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Brand.textMuted,
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
                const Text(
                  'Recovery',
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
                  'One day at a time — with tools for the hard minutes.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Brand.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                // SOS — free for everyone.
                Material(
                  color: const Color(0x14E12D23),
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
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.surfing_rounded,
                              size: 22,
                              color: Brand.red,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Craving right now?',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Brand.ink,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Urges pass. Surf this one — 8 guided '
                                  'minutes.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Brand.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: Brand.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const SectionHeader(title: 'In the moment'),
                const SizedBox(height: 10),
                _toolCard(
                  icon: Icons.psychology_alt_rounded,
                  accent: Brand.yellow,
                  title: 'HALT check',
                  detail: 'Hungry, angry, lonely, tired — find out what the '
                      'craving is standing in for.',
                  open: (_) => const HaltScreen(),
                ),
                _toolCard(
                  icon: Icons.movie_filter_rounded,
                  accent: Brand.red,
                  title: 'Play the tape forward',
                  detail: 'Watch the rest of the film before you decide, '
                      'then keep it in your journal.',
                  open: (_) => const TapeForwardScreen(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeader(title: 'My commitments'),
                    ),
                    if (_premium)
                      TextButton(
                        onPressed: _addHabitSheet,
                        child: const Text('+ Add'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_premium)
                  _lockedCard(
                    'Count every day, pledge each morning, and celebrate '
                    'milestones.',
                  )
                else if (_error)
                  Column(
                    children: [
                      const Text(
                        'Couldn\'t load your recovery data.',
                        style:
                            TextStyle(fontSize: 13.5, color: Brand.textMuted),
                      ),
                      TextButton(
                          onPressed: _load, child: const Text('Try again')),
                    ],
                  )
                else if (habits == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Brand.ink,
                        strokeWidth: 2.6,
                      ),
                    ),
                  )
                else if (habits.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'What are you leaving behind? Add it — we\'ll count '
                      'every day with you.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Brand.textMuted,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  for (final habit in habits) _habitCard(habit),
                const SizedBox(height: 4),
                _toolCard(
                  icon: Icons.emoji_events_rounded,
                  accent: Brand.blue,
                  title: 'Milestones',
                  detail: 'Every marker, reached and ahead, for each '
                      'commitment.',
                  open: (_) => const MilestonesScreen(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: SectionHeader(title: 'Trigger tracker'),
                    ),
                    if (_premium)
                      TextButton(
                        onPressed: _logCravingSheet,
                        child: const Text('+ Log'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_premium)
                  _lockedCard(
                    'Log cravings as they happen and learn what sets '
                    'them off.',
                  )
                else if (cravings != null) ...[
                  if (_topTrigger != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x1FFAB414),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insights_rounded,
                              size: 18, color: Brand.ink),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your most common trigger lately: '
                              '${_topTrigger!.toLowerCase()}. Naming it is '
                              'half the battle.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Brand.ink,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (cravings.isEmpty)
                    const Text(
                      'Nothing logged yet. Next time a craving hits, ride '
                      'it out and note it here.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Brand.textMuted,
                        height: 1.5,
                      ),
                    )
                  else
                    for (final log in cravings) _cravingRow(log),
                ],
                const SizedBox(height: 16),
                _toolCard(
                  icon: Icons.query_stats_rounded,
                  accent: Brand.ink,
                  title: 'Trigger insights',
                  detail: 'What sets them off, when they land, and how hard '
                      '— over the last 90 days.',
                  open: (_) => const TriggerInsightsScreen(),
                ),
                const SizedBox(height: 16),
                const CrisisFooter(
                  textAlign: TextAlign.left,
                  trailing: ' Recovery is easier with backup — a licensed '
                      'therapist here is never far away.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
