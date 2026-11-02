import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../brand_layout.dart';
import '../l10n/l10n.dart';
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
        _say(careErrorMessage(e, context.l10n.careDetailFailed));
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
            child: Text(context.l10n.commonBack),
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
    _say(context.l10n.careDetailBooked);
  }

  Future<void> _cancel() async {
    final request = _item.request;
    final l10n = context.l10n;
    final session = request.isConfirmed;
    final ok = await _confirm(
      session ? l10n.careCancelSessionTitle : l10n.careCancelRequestTitle,
      !session
          ? l10n.careCancelRequestBody
          : request.paymentStatus == 'paid'
              ? l10n.careCancelSessionPaidBody
              : l10n.careCancelSessionBody,
      session ? l10n.careCancelSessionAction : l10n.careCancelRequestAction,
      destructive: true,
    );
    if (!ok) return;
    await _run(
      () => widget.repository.cancelRequest(request.id),
      l10n.careCancelled,
    );
  }

  Future<void> _setPayment(String status) async {
    final l10n = context.l10n;
    final (title, body, action) = switch (status) {
      'paid' => (
          l10n.carePayPaidTitle,
          l10n.carePayPaidBody,
          l10n.carePayMarkPaid,
        ),
      'waived' => (
          l10n.carePayWaiveTitle,
          l10n.carePayWaiveBody,
          l10n.carePayWaive,
        ),
      _ => (
          l10n.carePayUnpaidTitle,
          l10n.carePayUnpaidBody,
          l10n.carePayMarkUnpaid,
        ),
    };
    if (!await _confirm(title, body, action)) return;
    await _run(
      () => widget.repository.setPayment(_item.request.id, status),
      l10n.carePaymentUpdated,
    );
  }

  String _statusLabel(AppLocalizations l10n) {
    final request = _item.request;
    return switch (request.status) {
      'awaiting_payment' => l10n.careStatusAwaitingPayment,
      'pending' => l10n.careStatusPending,
      'confirmed' when request.needsPayment => l10n.careStatusMatchedUnpaid,
      'confirmed' => l10n.careStatusBooked,
      'completed' when request.wasMissed => l10n.careStatusMissed,
      'completed' => request.completedAt == null
          ? l10n.careStatusCompleted
          : l10n.careStatusCompletedOn(formatDate(request.completedAt!)),
      'cancelled' when request.closeReason == 'therapist_no_show' =>
        l10n.careStatusTherapistNoShow,
      'cancelled' when request.closeReason == 'nobody_joined' =>
        l10n.careStatusNobodyJoined,
      'cancelled' when request.closeReason == 'unpaid' =>
        l10n.careStatusNeverPaid,
      'cancelled' when request.submittedAt == null =>
        l10n.careStatusDiscarded,
      _ => l10n.careStatusCancelled,
    };
  }

  String _paymentLabel(AppLocalizations l10n) {
    final request = _item.request;
    if (request.isFreeSession) return l10n.careFreeFirstSession;
    final price = request.priceLabel;
    final paidAt = _item.paidAt;
    final refunded = _item.refundedAt;
    return switch (request.paymentStatus) {
      'paid' when paidAt != null => l10n.carePaidOn(price, formatDate(paidAt)),
      'paid' => l10n.carePaid(price),
      'waived' => l10n.careWaived(price),
      _ when refunded != null =>
        l10n.careRefundedOn(price, formatDate(refunded)),
      _ => l10n.careNotPaidYet(price),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final request = _item.request;
    final email = _item.clientEmail;
    final note = request.note?.trim() ?? '';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_item.clientLabel(l10n))),
        body: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              CareSection(
                title: l10n.careSectionClient,
                children: [
                  InfoLine(
                    Icons.person_outline_rounded,
                    _item.clientName ?? l10n.careNoName,
                  ),
                  if (email != null)
                    InfoLine(
                      Icons.mail_outline_rounded,
                      email,
                      trailing: IconButton(
                        tooltip: l10n.careCopyEmail,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 18,
                          color: c.textMuted,
                        ),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: email));
                          if (mounted) _say(l10n.careEmailCopied);
                        },
                      ),
                    ),
                ],
              ),
              CareSection(
                title: l10n.careSectionRequest,
                children: [
                  InfoLine(Icons.chat_bubble_outline_rounded, request.topic),
                  InfoLine(
                    Icons.calendar_month_rounded,
                    request.availability.isEmpty
                        ? l10n.careMatchFlexible
                        : request.availability.join(' · '),
                  ),
                  if (note.isNotEmpty) InfoLine(Icons.notes_rounded, note),
                  InfoLine(
                    Icons.history_rounded,
                    l10n.careAsked(formatDateTime(request.createdAt)),
                  ),
                ],
              ),
              CareSection(
                title: l10n.careSectionSession,
                children: [
                  InfoLine(Icons.flag_outlined, _statusLabel(l10n)),
                  if (_item.therapistName != null)
                    InfoLine(Icons.psychology_outlined, _item.therapistName!),
                  if (request.scheduledAt != null)
                    InfoLine(
                      Icons.event_rounded,
                      l10n.careSessionWhen(formatDateTime(request.scheduledAt!),
                          request.durationMinutes),
                    ),
                  if (request.isActive) ...[
                    const SizedBox(height: 6),
                    ElevatedButton(
                      onPressed: _busy ? null : _match,
                      child: Text(request.isPending
                          ? l10n.careMatchWithTherapist
                          : l10n.careChangeTherapistOrTime),
                    ),
                  ],
                ],
              ),
              CareSection(
                title: l10n.careSectionPayment,
                children: [
                  InfoLine(Icons.payments_outlined, _paymentLabel(l10n)),
                  if (!request.isFreeSession &&
                      request.priceCents > 0 &&
                      request.status != 'cancelled')
                    Wrap(
                      spacing: 8,
                      children: [
                        if (request.needsPayment) ...[
                          TextButton(
                            onPressed: _busy ? null : () => _setPayment('paid'),
                            child: Text(l10n.carePayMarkPaid),
                          ),
                          TextButton(
                            onPressed:
                                _busy ? null : () => _setPayment('waived'),
                            child: Text(l10n.carePayWaive),
                          ),
                        ] else
                          TextButton(
                            onPressed:
                                _busy ? null : () => _setPayment('unpaid'),
                            child: Text(l10n.carePayMarkUnpaid),
                          ),
                      ],
                    ),
                ],
              ),
              if (request.isCompleted)
                CareSection(
                  title: l10n.careSectionAfter,
                  children: [
                    _feedback(
                      l10n.careNoteToClient,
                      text: request.clientSummary ?? l10n.careNoNote,
                    ),
                    _feedback(
                      l10n.careClientRating,
                      rating: _item.clientRating,
                      text: _item.clientComment ??
                          (_item.clientRating == null
                              ? l10n.careNotRatedYet
                              : null),
                    ),
                    _feedback(
                      l10n.careTherapistRating,
                      rating: _item.therapistRating,
                      text: _item.therapistComment ??
                          (_item.therapistRating == null
                              ? l10n.careNotRatedYet
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
                        ? l10n.careCancelThisSession
                        : l10n.careCancelThisRequest),
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
                    therapistFlagLabels(context.l10n)[flag] ?? flag,
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
