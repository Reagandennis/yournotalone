import 'dart:async';

import 'package:flutter/material.dart';

import '../brand.dart';
import '../home/home_ui.dart';
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
    SessionNotifications.instance.start(askPermission: true);
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
            e, 'Couldn\'t load your sessions — check your connection.'));
      }
    }
  }

  Future<void> _join(TherapistSession session) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          counterpartName: session.clientLabel,
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FinishSessionSheet(session: session, repository: _repo),
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(session.isCompleted
            ? 'Saved.'
            : 'Session finished — thank you.'),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('My sessions')),
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
          : RefreshIndicator(onRefresh: _load, child: _list(sessions)),
    );
  }

  Widget _list(List<TherapistSession> sessions) {
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
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Text(
              'No sessions yet. When the care team books one with you, it '
              'shows up here and you\'ll get an email.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Brand.textMuted,
                height: 1.55,
              ),
            ),
          ),
        if (upcoming.isNotEmpty) ...[
          const SectionHeader(title: 'Upcoming'),
          const SizedBox(height: 12),
          for (final session in upcoming) _upcomingCard(session, now),
          const SizedBox(height: 14),
        ],
        if (past.isNotEmpty) ...[
          const SectionHeader(title: 'Past'),
          const SizedBox(height: 12),
          for (final session in past) _pastCard(session),
        ],
      ],
    );
  }

  Widget _upcomingCard(TherapistSession session, DateTime now) {
    final state = session.joinStateAt(now);
    final canJoin = state == JoinState.open && session.paymentSettled;
    final hint = switch (state) {
      JoinState.tooEarly => 'The call opens 10 minutes before the start.',
      JoinState.over =>
        'The call has closed. Finish the session to close it out — '
            'otherwise it closes itself in a couple of hours.',
      _ when !session.paymentSettled =>
        'The client hasn\'t paid yet — the call opens once they do.',
      _ => 'The call is open.',
    };
    final note = session.note?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x0F3764CD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TherapistAvatar(name: session.clientLabel, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.clientLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Brand.ink,
                      ),
                    ),
                    Text(
                      session.topic,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Brand.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (session.isFreeSession)
                const StatusBadge('Free', color: Brand.blue)
              else if (!session.paymentSettled)
                const StatusBadge('Unpaid', color: Brand.red),
            ],
          ),
          const SizedBox(height: 12),
          if (session.scheduledAt != null)
            InfoLine(
              Icons.schedule_rounded,
              '${formatDateTime(session.scheduledAt!)} · '
              '${session.durationMinutes} min',
            ),
          if (note.isNotEmpty)
            InfoLine(Icons.notes_rounded, 'They wrote: “$note”'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: canJoin ? () => _join(session) : null,
            icon: const Icon(Icons.videocam_rounded),
            label: const Text('Join session'),
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Brand.textMuted),
          ),
          if (session.canFinishAt(now)) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => _finish(session),
              child: const Text('Finish session'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pastCard(TherapistSession session) {
    final when = session.scheduledAt ?? session.completedAt;
    final summary = session.clientSummary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Brand.border, width: 1.2),
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
                        session.clientLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      Text(
                        [session.topic, if (when != null) formatDate(when)]
                            .join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Brand.textMuted,
                        ),
                      ),
                      if (session.clientMissed) ...[
                        const SizedBox(height: 4),
                        const Text(
                          'The client didn\'t join the call.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Brand.red,
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
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Brand.ink,
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
                    session.didNotHappen ? 'Didn\'t happen' : 'Cancelled',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Brand.textMuted,
                    ),
                  )
                else if (session.myRating != null)
                  StarRow(rating: session.myRating!.toDouble())
                else
                  const StatusBadge('Rate', color: Brand.blue),
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
    final comment = _comment.text.trim();
    if (_rating == 0 && (comment.isNotEmpty || _flags.isNotEmpty)) {
      setState(() => _error = 'Add a star rating to send private feedback.');
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
            for (final flag in therapistFlagLabels.keys)
              if (_flags.contains(flag)) flag,
          ],
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = careErrorMessage(e, 'Couldn\'t save — check your connection.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.session.clientLabel;
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
              done ? 'Session with $name' : 'Finish your session with $name',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Brand.ink,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _summary,
              maxLines: 4,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'A note for $name (optional)',
                helperText: 'They see this in the app — a takeaway, or '
                    'something to practise. Keep clinical notes out of it.',
                helperMaxLines: 3,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'How did it go?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Brand.ink,
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
                    in therapistFlagLabels.entries)
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
              decoration: const InputDecoration(
                labelText: 'Private note for the care team (optional)',
                alignLabelWithHint: true,
                counterText: '',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only the care team sees your rating, flags and private note. '
              'Flagging a safety concern emails them straight away.',
              style: TextStyle(fontSize: 12, color: Brand.textMuted, height: 1.5),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: Brand.red),
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
                  : Text(done ? 'Save' : 'Finish session'),
            ),
          ],
        ),
      ),
    );
  }
}
