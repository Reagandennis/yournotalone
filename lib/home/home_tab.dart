import 'dart:async';

import 'package:flutter/material.dart';

import '../billing/nudges.dart';
import '../billing/pricing_copy.dart';
import '../brand.dart';
import '../discover/content_index.dart';
import '../discover/content_widgets.dart';
import '../discover/usage_store.dart';
import '../journal/journal_screen.dart';
import '../meditation/meditations_screen.dart';
import '../practice/practice_repository.dart';
import '../practice/practice_screen.dart';
import '../recovery/recovery_screen.dart';
import '../sounds/sounds_screen.dart';
import '../support/heavy_day_sheet.dart';
import '../therapy/session_format.dart';
import '../therapy/therapy_repository.dart';
import '../therapy/therapy_screen.dart';
import 'home_ui.dart';
import 'mood_face.dart';
import 'mood_history_screen.dart';
import 'mood_repository.dart';
import 'mood_scale.dart';

enum _QuickAction { comingSoon, journal, sounds, meditate, recovery }

class _QuickItem {
  const _QuickItem(
    this.icon,
    this.accent,
    this.title,
    this.sub, {
    this.action = _QuickAction.comingSoon,
    this.kinds = const {},
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String sub;
  final _QuickAction action;

  /// What opening content of these kinds counts towards, so the tiles
  /// people use most move to the front.
  final Set<ContentKind> kinds;
}

const _quickItems = [
  _QuickItem(
    Icons.self_improvement_rounded,
    Pillars.blue,
    'Meditate',
    'Breathe & settle',
    action: _QuickAction.meditate,
    kinds: {ContentKind.meditation, ContentKind.breathing},
  ),
  _QuickItem(
    Icons.edit_note_rounded,
    Pillars.red,
    'Journal',
    'Write it out',
    action: _QuickAction.journal,
    kinds: {ContentKind.prompt},
  ),
  _QuickItem(
    Icons.graphic_eq_rounded,
    Pillars.yellow,
    'Sounds',
    'Focus · sleep · calm',
    action: _QuickAction.sounds,
    kinds: {ContentKind.sound},
  ),
  _QuickItem(
    Icons.healing_rounded,
    Pillars.black,
    'Recovery',
    'One day at a time',
    action: _QuickAction.recovery,
    kinds: {ContentKind.recovery},
  ),
];

/// Home tab: greeting, a one-tap mood check-in that answers with
/// something to try, the week's moods, today's prompt, suggestions for the
/// time of day, the practice streak, quick access ordered by use, and the
/// therapy banner (or the next booked session).
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, this.practice, this.therapyRequests});

  /// Injectable so the practice strip can be driven with known sessions.
  final PracticeRepository? practice;

  /// Injectable so the session banner can be tested without a backend.
  final Future<List<TherapyRequest>> Function()? therapyRequests;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _moodRepo = MoodRepository();
  late final _practiceRepo = widget.practice ?? PracticeRepository();
  int? _mood;
  PracticeSummary? _practice;

  /// Check-ins from the last seven days; null until loaded.
  List<MoodEntry>? _week;
  TherapyRequest? _session;
  List<_QuickItem> _quick = _quickItems;

  @override
  void initState() {
    super.initState();
    // Re-light today's mood if one was already saved.
    _moodRepo
        .fetchTodayMoodIndex()
        .then((index) {
          if (mounted && index != null) setState(() => _mood = index);
        })
        .catchError((_) {});
    _moodRepo
        .fetchHistory(days: 7)
        .then((entries) {
          if (mounted) setState(() => _week = entries);
        })
        .catchError((_) {
          // The strip just stays hidden.
        });
    _practiceRepo
        .fetchSummary()
        .then((summary) {
          if (mounted) setState(() => _practice = summary);
        })
        .catchError((_) {
          // The strip just stays hidden; it's not worth an error here.
        });
    (widget.therapyRequests ?? () => TherapyRepository().fetchRequests())()
        .then((requests) {
          if (mounted) {
            setState(() => _session = _upcoming(requests, DateTime.now()));
          }
        })
        .catchError((_) {
          // No session to show; the plain banner stays.
        });
    unawaited(_orderQuickAccess());
  }

  /// Puts the tiles people actually open first. A stable sort, so with no
  /// history (or a tie) the designed order stands.
  Future<void> _orderQuickAccess() async {
    final counts = await UsageStore.instance.openCounts();
    if (counts.isEmpty || !mounted) return;
    int uses(_QuickItem item) =>
        item.kinds.fold(0, (sum, k) => sum + (counts[k.name] ?? 0));
    final ordered = [..._quickItems]
      ..sort((a, b) {
        final byUse = uses(b).compareTo(uses(a));
        return byUse != 0
            ? byUse
            : _quickItems.indexOf(a).compareTo(_quickItems.indexOf(b));
      });
    setState(() => _quick = ordered);
  }

  /// The booked session still to come (or open now), else a paid request
  /// the care team is still matching.
  static TherapyRequest? _upcoming(
    List<TherapyRequest> requests,
    DateTime now,
  ) {
    final booked = [
      for (final r in requests)
        if (r.isConfirmed &&
            r.scheduledAt != null &&
            r.joinStateAt(now) != JoinState.over)
          r,
    ]..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    if (booked.isNotEmpty) return booked.first;
    for (final r in requests) {
      if (r.isPending) return r;
    }
    return null;
  }

  Future<void> _selectMood(int index) async {
    final firstTime = _mood == null;
    setState(() {
      _mood = index;
      _week = _withToday(index);
    });
    // An "Awful" day is the one moment the app knows someone is
    // struggling. Offer the door straight away — before the save, which
    // may be slow or fail offline — without forcing them through it.
    if (index == 0) unawaited(showHeavyDaySheet(context));
    try {
      await _moodRepo.saveMood(index);
      if (!mounted) return;
      if (index != 0 && firstTime) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks for checking in.')),
        );
        unawaited(_nudgeAfterCheckins());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage(
                e,
                'Couldn\'t save your mood — check your connection.',
              ),
            ),
          ),
        );
      }
    }
  }

  /// The week strip with today's pick in it, before the save comes back.
  List<MoodEntry>? _withToday(int index) {
    final week = _week;
    if (week == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      MoodEntry(date: today, index: index),
      for (final e in week)
        if (!DateUtils.isSameDay(e.date, today)) e,
    ];
  }

  /// The third check-in is the first sign of a habit — the one moment an
  /// offer to keep the record is about something they're already doing.
  /// Once per account, free users only.
  Future<void> _nudgeAfterCheckins() async {
    if (isPremiumUser()) return;
    try {
      final history = await _moodRepo.fetchHistory(days: 30);
      if (history.length < 3 || !mounted) return;
      if (!await Nudges.claim('mood3') || !mounted) return;
      showUpgradeSheet(
        context,
        source: 'nudge:mood3',
        title: 'Three check-ins in',
        message:
            'You\'re building a habit. Premium keeps every check-in '
            'and shows you how the weeks are actually going — and '
            '$introOffer.',
      );
    } catch (e) {
      debugPrint('Check-in nudge skipped: $e');
    }
  }

  void _openMoodHistory() {
    if (!isPremiumUser()) {
      showUpgradeSheet(
        context,
        title: 'Mood history is part of Premium',
        message:
            'Checking in is always free. Premium keeps the record and '
            'shows you the pattern — and $introOffer.',
        source: 'home:mood_week',
      );
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MoodHistoryScreen()));
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  /// What the app remembers about you. Hidden until there is something to
  /// show, so a first-time user isn't greeted by a row of zeroes.
  Widget _practiceCard() {
    final c = context.brand;
    final summary = _practice;
    if (summary == null || summary.isEmpty) return const SizedBox.shrink();
    final last = summary.last!;
    final resume = contentForPractice(last);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Material(
        color: c.tint(Pillars.blue, 0.06),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PracticeScreen())),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary.dayStreak > 1
                            ? '${summary.dayStreak} days in a row'
                            : 'Your practice',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: c.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.minutesThisWeek.round()} minutes this week · '
                  '${summary.sessions} sessions in all',
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.chip,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        last.kind.icon,
                        size: 17,
                        color: c.accent(last.kind.color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Last time: ${last.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: c.ink),
                      ),
                    ),
                    // One tap back into it, rather than finding it again.
                    if (resume != null)
                      TextButton.icon(
                        onPressed: () => openContent(
                          context,
                          resume,
                          source: 'home:continue',
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Continue'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One suggestion for the mood just picked, and a way to see the rest.
  Widget _moodSuggestion(int index) {
    final c = context.brand;
    final needs = Need.forMood(index);
    final picks = recommend(
      needs: needs,
      count: 1,
      now: DateTime.now(),
      premium: isPremiumUser(),
    );
    if (picks.isEmpty) return const SizedBox.shrink();
    final need = needs.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(
          switch (index) {
            0 || 1 => 'Something that might help',
            2 => 'Something for right now',
            _ => 'Something to keep it going',
          },
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ContentRow(item: picks.first, source: 'home:mood'),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(ContentListScreen.route(ContentListScreen.forNeed(need))),
            child: Text(
              'More for “${need.label.toLowerCase()}”',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  /// The last seven days as small faces, today on the right. Shown once
  /// there's at least one check-in to put in it.
  Widget _weekStrip() {
    final c = context.brand;
    final week = _week;
    if (week == null || week.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _openMoodHistory,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: c.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your week',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  ),
                ),
                Text(
                  'History',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: c.blue,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: c.blue),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var back = 6; back >= 0; back--)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = DateTime(
                          today.year,
                          today.month,
                          today.day - back,
                        );
                        final entry = week
                            .where((e) => DateUtils.isSameDay(e.date, day))
                            .firstOrNull;
                        return Column(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: entry == null
                                  ? Center(
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: moodIdleColor(c),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : MoodFace(
                                      level: moodLevels[entry.index],
                                      size: 24,
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              letters[day.weekday - 1],
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: back == 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: back == 0 ? c.ink : c.textMuted,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _moodCard() {
    final c = context.brand;
    // Five faces have to fit the width, whatever the phone: work out the
    // per-face budget and cap it at the size the design wants.
    final width = MediaQuery.sizeOf(context).width;
    final faceSize = ((width - 56 - 36) / 5).clamp(30.0, 48.0);
    final mood = _mood;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border, width: 1.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling today?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (i, level) in moodLevels.indexed)
                // Expanded, because five fixed-width faces run off a
                // 320px screen — and wider ones once system text is
                // scaled up.
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _selectMood(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 1,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          // All five in colour until one is picked; then
                          // the others step back and the pick grows.
                          AnimatedScale(
                            scale: mood == i ? 1.14 : 1.0,
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutBack,
                            child: MoodFace(
                              level: level,
                              size: faceSize,
                              dimmed: mood != null && mood != i,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            level.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: mood == i
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: mood == i
                                  ? c.accent(level.color)
                                  : c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: mood == null
                ? const SizedBox(width: double.infinity)
                : _moodSuggestion(mood),
          ),
          _weekStrip(),
        ],
      ),
    );
  }

  /// Today's prompt or short read: changes at midnight, so there's always
  /// something new to open.
  Widget _todayCard(ContentItem item) {
    final c = context.brand;
    final locked = item.premium && !isPremiumUser();
    return Material(
      color: c.tint(item.accent, 0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openContent(context, item, source: 'home:today'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.kind == ContentKind.prompt
                          ? 'TODAY\'S PROMPT'
                          : 'TODAY\'S READ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: c.accent(item.accent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 8),
                          const PremiumChip(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.chip,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 22, color: c.accent(item.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickCard(_QuickItem item) {
    final c = context.brand;
    return Material(
      color: c.tint(item.accent, 0.07),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (item.kinds.isNotEmpty) {
            unawaited(UsageStore.instance.recordOpen(item.kinds.first));
          }
          switch (item.action) {
            case _QuickAction.journal:
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const JournalScreen()));
            case _QuickAction.sounds:
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SoundsScreen()));
            case _QuickAction.meditate:
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MeditationsScreen()),
              );
            case _QuickAction.recovery:
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RecoveryScreen()));
            case _QuickAction.comingSoon:
              showComingSoon(context, item.title);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: c.chip,
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, size: 20, color: c.accent(item.accent)),
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Today, 17:00", "Tomorrow, 9:30", else "Thu 30 Oct, 17:00".
  static String _when(DateTime at, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    return switch (day.difference(today).inDays) {
      0 => 'Today, ${formatTime(at)}',
      1 => 'Tomorrow, ${formatTime(at)}',
      _ => formatDateTime(at),
    };
  }

  /// The therapy banner: the next booked session when there is one, a
  /// request being matched, or the invitation to book.
  Widget _therapyBanner() {
    final c = context.brand;
    final session = _session;
    final now = DateTime.now();
    final open = session != null && session.joinStateAt(now) == JoinState.open;
    final (title, sub) = switch (session) {
      final s? when s.isConfirmed && s.scheduledAt != null => (
        'Your session · ${_when(s.scheduledAt!, now)}',
        open
            ? 'It\'s open now — tap to join.'
            : 'Tap for the details, or to join when it opens.',
      ),
      final s? when s.isPending => (
        'Finding your therapist',
        'We\'ll let you know as soon as your session is booked.',
      ),
      _ => ('Talk to a real therapist', '\$20 a session, paid when you book.'),
    };
    return Material(
      color: open ? c.tint(Pillars.red, 0.10) : c.tint(Pillars.blue, 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(TherapyScreen.route()),
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
                  session?.isConfirmed == true
                      ? Icons.videocam_rounded
                      : Icons.favorite_rounded,
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
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: TextStyle(fontSize: 13, color: c.textMuted),
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
    );
  }

  @override
  Widget build(BuildContext context) =>
      PremiumBuilder(builder: (context, premium) => _page(context, premium));

  Widget _page(BuildContext context, bool premium) {
    final c = context.brand;
    final now = DateTime.now();
    final today = dailyPick(now: now, premium: premium);
    final dayPart = DayPart.of(now);
    final forNow = recommend(
      dayPart: dayPart,
      count: 5,
      now: now,
      premium: premium,
      exclude: {today.id},
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting,
                    style: TextStyle(fontSize: 14, color: c.textMuted),
                  ),
                  Text(
                    firstNameOf(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Image.asset(c.pillarsAsset, height: 44),
          ],
        ),
        const SizedBox(height: 12),
        const PillarStripe(),
        const SizedBox(height: 24),
        _moodCard(),
        const SizedBox(height: 20),
        _todayCard(today),
        const SizedBox(height: 28),
        if (forNow.isNotEmpty) ...[
          SectionHeader(title: dayPart.heading),
          const SizedBox(height: 12),
          ContentStrip(items: forNow, source: 'home:${dayPart.name}'),
          const SizedBox(height: 28),
        ],
        _practiceCard(),
        const SectionHeader(title: 'Quick access'),
        const SizedBox(height: 12),
        // A fixed aspect ratio ties tile height to screen width, so the
        // contents overflowed on narrow phones and clipped at larger text
        // sizes. An absolute extent that tracks the text scale doesn't.
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 80 + 38 * MediaQuery.textScalerOf(context).scale(1),
          ),
          children: [for (final item in _quick) _quickCard(item)],
        ),
        const SizedBox(height: 24),
        _therapyBanner(),
      ],
    );
  }
}
