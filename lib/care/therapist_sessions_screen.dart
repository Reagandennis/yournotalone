import 'dart:async';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../brand_layout.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
import '../notifications/notification_permission.dart';
import '../notifications/session_notifications.dart';
import '../therapy/call_screen.dart';
import '../therapy/session_format.dart';
import '../therapy/session_widgets.dart';
import '../therapy/therapy_repository.dart';
import 'care_repository.dart';
import 'care_widgets.dart';

/// A therapist's sessions: join the call when it's time, then finish it
/// with a note for the client and a rating only the care team sees.
class TherapistSessionsScreen extends StatefulWidget {
  const TherapistSessionsScreen({super.key, this.repository, this.clock});

  final CareRepository? repository;

  /// Injectable so tests can put "now" anywhere around a session.
  final DateTime Function()? clock;

  static const routeName = '/therapist-sessions';

  /// The route every caller pushes, named so a notification tap can find
  /// the screen if it's already open instead of stacking another.
  static Route<void> route() => MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (_) => const TherapistSessionsScreen(),
      );

  @override
  State<TherapistSessionsScreen> createState() =>
      _TherapistSessionsScreenState();
}

class _TherapistSessionsScreenState extends State<TherapistSessionsScreen> {
  late final _repo = widget.repository ?? CareRepository();
  List<TherapistSession>? _sessions;
  String? _error;

  /// Moves the Join button along as start times come and go.
  Timer? _ticker;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
    SessionNotifications.instance.start();
    // Therapists miss sessions too: ask properly, and point at Settings if
    // it was refused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NotificationPermission.instance
            .ensure(context, reason: NotificationReasons.therapist);
      }
    });
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final sessions = await _repo.listMySessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = careErrorMessage(
            e, context.l10n.careSessionsCouldNotLoad));
      }
    }
  }

  Future<void> _join(TherapistSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: CallScreen.routeName),
        builder: (_) => CallScreen(
          counterpartName: session.clientLabel(context.l10n),
          connect: () => _repo.joinSession(session.id),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _finish(TherapistSession session) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FinishSessionSheet(session: session, repository: _repo),
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(session.isCompleted
            ? context.l10n.careSessionsSaved
            : context.l10n.careSessionsFinished),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.careSessionsTitle)),
      body: sessions == null
          ? _error != null
              ? LoadFailed(
                  message: _error!,
                  onRetry: () {
                    setState(() => _error = null);
                    _load();
                  },
                )
              : const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ReadableWidth(child: _list(sessions)),
            ),
    );
  }

  Widget _list(List<TherapistSession> sessions) {
    final c = context.brand;
    final l10n = context.l10n;
    final now = _now();
    final upcoming = [
      for (final s in sessions)
        if (s.isConfirmed) s,
    ]..sort((a, b) => (a.scheduledAt ?? now).compareTo(b.scheduledAt ?? now));
    final past = [
      for (final s in sessions)
        if (!s.isConfirmed) s,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Text(
              l10n.careSessionsEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: c.textMuted,
                height: 1.55,
              ),
            ),
          ),
        if (upcoming.isNotEmpty) ...[
          SectionHeader(title: l10n.careSessionsUpcoming),
          const SizedBox(height: 12),
          for (final session in upcoming) _upcomingCard(session, now),
          const SizedBox(height: 14),
        ],
        if (past.isNotEmpty) ...[
          SectionHeader(title: l10n.careSessionsPast),
          const SizedBox(height: 12),
          for (final session in past) _pastCard(session),
        ],
      ],
    );
  }

  Widget _upcomingCard(TherapistSession session, DateTime now) {
    final c = context.brand;
    final l10n = context.l10n;
    final state = session.joinStateAt(now);
    final canJoin = state == JoinState.open && session.paymentSettled;
    final hint = switch (state) {
      JoinState.tooEarly => l10n.careSessionsTooEarly,
      JoinState.over => l10n.careSessionsOver,
      _ when !session.paymentSettled => l10n.careSessionsUnpaid,
      _ => l10n.careSessionsOpen,
    };
    final note = session.note?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.tint(Pillars.blue, 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TherapistAvatar(name: session.clientLabel(l10n), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.clientLabel(l10n),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      session.topic,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (session.isFreeSession)
                StatusBadge(l10n.carePaymentFree, color: Pillars.blue)
              else if (!session.paymentSettled)
                StatusBadge(l10n.carePaymentUnpaid, color: Pillars.red),
            ],
          ),
          const SizedBox(height: 12),
          if (session.scheduledAt != null)
            InfoLine(
              Icons.schedule_rounded,
              l10n.careSessionWhen(formatDateTime(session.scheduledAt!),
                  session.durationMinutes),
            ),
          if (note.isNotEmpty)
            InfoLine(Icons.notes_rounded, l10n.careSessionsTheyWrote(note)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: canJoin ? () => _join(session) : null,
            icon: const Icon(Icons.videocam_rounded),
            label: Text(l10n.careSessionsJoin),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: c.textMuted),
          ),
          if (session.canFinishAt(now)) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => _finish(session),
              child: Text(l10n.careSessionsFinish),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pastCard(TherapistSession session) {
    final c = context.brand;
    final l10n = context.l10n;
    final when = session.scheduledAt ?? session.completedAt;
    final summary = session.clientSummary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: session.isCompleted ? () => _finish(session) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.clientLabel(l10n),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        [session.topic, if (when != null) formatDate(when)]
                            .join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
                        ),
                      ),
                      if (session.clientMissed) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.careSessionsClientMissed,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.red,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (session.isCompleted && summary != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.ink,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (session.isCancelled)
                  Text(
                    session.didNotHappen
                        ? l10n.careSessionsDidNotHappen
                        : l10n.careStatusCancelled,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  )
                else if (session.myRating != null)
                  StarRow(rating: session.myRating!.toDouble())
                else
                  StatusBadge(l10n.careSessionsRate, color: Pillars.blue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Close out a session: a note the client sees, and a rating, flags and
/// comment only the care team sees. Also edits all of that afterwards.
class _FinishSessionSheet extends StatefulWidget {
  const _FinishSessionSheet({required this.session, required this.repository});

  final TherapistSession session;
  final CareRepository repository;

  @override
  State<_FinishSessionSheet> createState() => _FinishSessionSheetState();
}

class _FinishSessionSheetState extends State<_FinishSessionSheet> {
  late final _summary =
      TextEditingController(text: widget.session.clientSummary);
  late final _comment = TextEditingController(text: widget.session.myComment);
  late int _rating = widget.session.myRating ?? 0;
  late final _flags = <String>{...widget.session.myFlags};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _summary.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final comment = _comment.text.trim();
    if (_rating == 0 && (comment.isNotEmpty || _flags.isNotEmpty)) {
      setState(() => _error = l10n.careFinishNeedsRating);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository
          .completeSession(widget.session.id, _summary.text.trim());
      if (_rating > 0) {
        await widget.repository.rateClient(
          widget.session.id,
          rating: _rating,
          comment: comment.isEmpty ? null : comment,
          flags: [
            for (final flag in therapistFlagLabels(l10n).keys)
              if (_flags.contains(flag)) flag,
          ],
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = careErrorMessage(e, l10n.careCouldNotSave);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final name = widget.session.clientLabel(l10n);
    final done = widget.session.isCompleted;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              done
                  ? l10n.careFinishTitleDone(name)
                  : l10n.careFinishTitle(name),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _summary,
              maxLines: 4,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.careFinishNoteLabel(name),
                helperText: l10n.careFinishNoteHelp,
                helperMaxLines: 3,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.careFinishHowDidItGo,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 4),
            StarRatingInput(
              value: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final MapEntry(key: flag, value: label)
                    in therapistFlagLabels(l10n).entries)
                  ChoicePill(
                    label: label,
                    selected: _flags.contains(flag),
                    onTap: () => setState(() {
                      if (!_flags.remove(flag)) _flags.add(flag);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: l10n.careFinishPrivateNote,
                alignLabelWithHint: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.careFinishPrivacy,
              style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.5),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: c.red),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(done ? l10n.commonSave : l10n.careSessionsFinish),
            ),
          ],
        ),
      ),
    );
  }
}
