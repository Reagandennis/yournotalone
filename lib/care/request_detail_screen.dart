import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../brand_layout.dart';
import '../therapy/session_format.dart';
import '../therapy/session_widgets.dart';
import 'care_repository.dart';
import 'care_widgets.dart';
import 'match_screen.dart';

/// One therapy request, for the care team: who asked and what for, the
/// match, the payment, and how both sides rated it afterwards.
///
/// Pops with true when anything changed, so the dashboard reloads.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({
    super.key,
    required this.item,
    required this.repository,
  });

  final AdminTherapyRequest item;
  final CareRepository repository;

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late AdminTherapyRequest _item = widget.item;
  bool _busy = false;
  bool _changed = false;

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _reload() async {
    final all = await widget.repository.listRequests();
    final fresh =
        all.where((r) => r.request.id == _item.request.id).firstOrNull;
    if (fresh != null && mounted) setState(() => _item = fresh);
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      _changed = true;
      await _reload();
      if (mounted) _say(done);
    } catch (e) {
      if (mounted) {
        _say(careErrorMessage(e, 'That didn\'t work — check your connection.'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String body,
    String action, {
    bool destructive = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: context.brand.red)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _match() async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            MatchScreen(item: _item, repository: widget.repository),
      ),
    );
    if (booked != true || !mounted) return;
    _changed = true;
    setState(() => _busy = true);
    try {
      await _reload();
    } catch (_) {
      // The booking went through; the refreshed details can wait.
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _say('Booked — the client and therapist have been emailed.');
  }

  Future<void> _cancel() async {
    final request = _item.request;
    final session = request.isConfirmed;
    final refund = request.paymentStatus == 'paid'
        ? ' They\'ve paid, so refund them in the Paystack dashboard '
            '(Play Console for older in-app payments).'
        : '';
    final ok = await _confirm(
      session ? 'Cancel this session?' : 'Cancel this request?',
      session
          ? 'The client and therapist are emailed that it\'s cancelled.$refund'
          : 'The client can request again whenever they like.',
      session ? 'Cancel session' : 'Cancel request',
      destructive: true,
    );
    if (!ok) return;
    await _run(
      () => widget.repository.cancelRequest(request.id),
      'Cancelled.',
    );
  }

  Future<void> _setPayment(String status) async {
    final (title, body, action) = switch (status) {
      'paid' => (
          'Record a payment?',
          'Use this when they paid outside the app. The Join button '
              'unlocks for them straight away.',
          'Mark as paid',
        ),
      'waived' => (
          'Waive the fee?',
          'They won\'t be charged for this session, and can join straight '
              'away.',
          'Waive fee',
        ),
      _ => (
          'Mark as unpaid?',
          'They\'ll need to pay before they can join.',
          'Mark as unpaid',
        ),
    };
    if (!await _confirm(title, body, action)) return;
    await _run(
      () => widget.repository.setPayment(_item.request.id, status),
      'Payment updated.',
    );
  }

  String get _statusLabel {
    final request = _item.request;
    return switch (request.status) {
      'awaiting_payment' => 'Not sent yet — the client hasn\'t paid',
      'pending' => 'Waiting to be matched',
      'confirmed' when request.needsPayment => 'Matched — waiting for payment',
      'confirmed' => 'Booked',
      'completed' when request.wasMissed => 'Completed — the client '
          'didn\'t join, so the session counts as used',
      'completed' => request.completedAt == null
          ? 'Completed'
          : 'Completed ${formatDate(request.completedAt!)}',
      'cancelled' when request.closeReason == 'therapist_no_show' =>
        'Cancelled — the therapist didn\'t join the call',
      'cancelled' when request.closeReason == 'nobody_joined' =>
        'Cancelled — nobody joined the call',
      'cancelled' when request.closeReason == 'unpaid' =>
        'Cancelled — never paid',
      'cancelled' when request.submittedAt == null =>
        'Discarded before it was paid for',
      _ => 'Cancelled',
    };
  }

  String get _paymentLabel {
    final request = _item.request;
    if (request.isFreeSession) return 'Free first session';
    final paidOn =
        _item.paidAt == null ? '' : ' on ${formatDate(_item.paidAt!)}';
    final refunded = _item.refundedAt;
    return switch (request.paymentStatus) {
      'paid' => '${request.priceLabel} · paid$paidOn',
      'waived' => '${request.priceLabel} · waived',
      _ when refunded != null =>
        '${request.priceLabel} · refunded on '
            '${formatDate(refunded)}, not paid',
      _ => '${request.priceLabel} · not paid yet',
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final request = _item.request;
    final email = _item.clientEmail;
    final note = request.note?.trim() ?? '';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_item.clientLabel)),
        body: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              CareSection(
                title: 'Client',
                children: [
                  InfoLine(
                    Icons.person_outline_rounded,
                    _item.clientName ?? 'No name given',
                  ),
                  if (email != null)
                    InfoLine(
                      Icons.mail_outline_rounded,
                      email,
                      trailing: IconButton(
                        tooltip: 'Copy email',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: c.textMuted,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: email));
                          if (mounted) _say('Email copied.');
                        },
                      ),
                    ),
                ],
              ),
              CareSection(
                title: 'Request',
                children: [
                  InfoLine(Icons.chat_bubble_outline_rounded, request.topic),
                  InfoLine(
                    Icons.calendar_month_rounded,
                    request.availability.isEmpty
                        ? 'Flexible'
                        : request.availability.join(' · '),
                  ),
                  if (note.isNotEmpty) InfoLine(Icons.notes_rounded, note),
                  InfoLine(
                    Icons.history_rounded,
                    'Asked ${formatDateTime(request.createdAt)}',
                  ),
                ],
              ),
              CareSection(
                title: 'Session',
                children: [
                  InfoLine(Icons.flag_outlined, _statusLabel),
                  if (_item.therapistName != null)
                    InfoLine(Icons.psychology_outlined, _item.therapistName!),
                  if (request.scheduledAt != null)
                    InfoLine(
                      Icons.event_rounded,
                      '${formatDateTime(request.scheduledAt!)} · '
                      '${request.durationMinutes} min',
                    ),
                  if (request.isActive) ...[
                    const SizedBox(height: 6),
                    ElevatedButton(
                      onPressed: _busy ? null : _match,
                      child: Text(request.isPending
                          ? 'Match with a therapist'
                          : 'Change therapist or time'),
                    ),
                  ],
                ],
              ),
              CareSection(
                title: 'Payment',
                children: [
                  InfoLine(Icons.payments_outlined, _paymentLabel),
                  if (!request.isFreeSession &&
                      request.priceCents > 0 &&
                      request.status != 'cancelled')
                    Wrap(
                      spacing: 8,
                      children: [
                        if (request.needsPayment) ...[
                          TextButton(
                            onPressed: _busy ? null : () => _setPayment('paid'),
                            child: const Text('Mark as paid'),
                          ),
                          TextButton(
                            onPressed:
                                _busy ? null : () => _setPayment('waived'),
                            child: const Text('Waive fee'),
                          ),
                        ] else
                          TextButton(
                            onPressed:
                                _busy ? null : () => _setPayment('unpaid'),
                            child: const Text('Mark as unpaid'),
                          ),
                      ],
                    ),
                ],
              ),
              if (request.isCompleted)
                CareSection(
                  title: 'After the session',
                  children: [
                    _feedback(
                      'Note to the client',
                      text: request.clientSummary ?? 'No note written.',
                    ),
                    _feedback(
                      'Client\'s rating',
                      rating: _item.clientRating,
                      text: _item.clientComment ??
                          (_item.clientRating == null ? 'Not rated yet.' : null),
                    ),
                    _feedback(
                      'Therapist\'s rating — private',
                      rating: _item.therapistRating,
                      text: _item.therapistComment ??
                          (_item.therapistRating == null
                              ? 'Not rated yet.'
                              : null),
                      flags: _item.therapistFlags,
                    ),
                  ],
                ),
              if (request.isActive)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _busy ? null : _cancel,
                    style: TextButton.styleFrom(foregroundColor: c.red),
                    child: Text(request.isConfirmed
                        ? 'Cancel this session'
                        : 'Cancel this request'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedback(
    String title, {
    int? rating,
    String? text,
    List<String> flags = const [],
  }) {
    final c = context.brand;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.tint(Pillars.black, 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              if (rating != null) StarRow(rating: rating.toDouble()),
            ],
          ),
          if (text != null) ...[
            const SizedBox(height: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: c.textMuted,
                height: 1.45,
              ),
            ),
          ],
          if (flags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final flag in flags)
                  StatusBadge(
                    therapistFlagLabels[flag] ?? flag,
                    color: flag == 'safety_concern'
                        ? Pillars.red
                        : Pillars.black,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
