import 'dart:async';

import 'package:flutter/material.dart';

import '../billing/purchases_service.dart';
import '../billing/session_payments.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../notifications/session_notifications.dart';
import '../support/crisis_screen.dart';
import 'call_screen.dart';
import 'session_format.dart';
import 'session_widgets.dart';
import 'therapy_art.dart';
import 'therapy_repository.dart';

const _timeSlots = [
  'Weekday mornings',
  'Weekday afternoons',
  'Weekday evenings',
  'Weekends',
];

/// Talk to a real therapist: request a private session, see who you've been
/// matched with and when, pay if it isn't the free one, join the video
/// call, and rate it afterwards.
class TherapyScreen extends StatefulWidget {
  const TherapyScreen({
    super.key,
    this.repository,
    this.payments,
    this.clock,
  });

  /// Injectable so the booking flow can be exercised without a backend.
  final TherapyRepository? repository;
  final SessionPayments? payments;

  /// Injectable so tests can put "now" anywhere around a session.
  final DateTime Function()? clock;

  @override
  State<TherapyScreen> createState() => _TherapyScreenState();
}

class _TherapyScreenState extends State<TherapyScreen> {
  late final _repo = widget.repository ?? TherapyRepository();
  late final _payments =
      widget.payments ?? SessionPayments(repository: _repo);
  final _noteController = TextEditingController();

  List<TherapyRequest>? _requests;
  Map<String, TherapistProfile> _therapists = const {};
  Map<String, int> _myRatings = const {};
  bool _failed = false;
  String? _topic;
  final _slots = <String>{};
  bool _submitting = false;
  bool _paying = false;

  /// Moves the Join button along as the start time comes and goes.
  Timer? _ticker;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
    // Schedules the reminder for a booked session straight away.
    SessionNotifications.instance.start();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && (_requests?.any((r) => r.isConfirmed) ?? false)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  /// [quiet] keeps what's on screen while it refreshes, for after an action.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _requests = null;
        _failed = false;
      });
    }
    try {
      final requests = await _repo.fetchRequests();
      final therapistIds = [
        for (final r in requests)
          if (r.therapistId != null) r.therapistId!,
      ];
      final therapists = therapistIds.isEmpty
          ? const <String, TherapistProfile>{}
          : await _repo.fetchTherapists(therapistIds);
      final ratings = requests.any((r) => r.isCompleted)
          ? await _repo.fetchMyRatings()
          : const <String, int>{};
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _therapists = therapists;
        _myRatings = ratings;
        _failed = false;
      });
    } catch (e) {
      if (mounted && !quiet) setState(() => _failed = true);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final topic = _topic;
    if (topic == null) return;
    setState(() => _submitting = true);
    try {
      await _repo.requestSession(
        topic: topic,
        availability: [
          for (final slot in _timeSlots)
            if (_slots.contains(slot)) slot,
        ],
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      _topic = null;
      _slots.clear();
      _noteController.clear();
      _say('Request sent — we\'ll let you know as soon as you\'re matched.');
      // Notifications are how they'll hear about the match and the reminder.
      unawaited(SessionNotifications.instance.start(askPermission: true));
      await _load();
    } catch (e) {
      if (mounted) {
        _say(errorMessage(
            e, 'Couldn\'t send your request — check your connection.'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(TherapyRequest request) async {
    final matched = request.isConfirmed;
    final keepsFreeSession = request.isFreeSession
        ? ' Your free first session stays yours.'
        : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(matched ? 'Cancel this session?' : 'Cancel this request?'),
        content: Text(
          matched
              ? 'We\'ll let your therapist know. You can book again whenever '
                  'you\'re ready.$keepsFreeSession'
              : 'No problem — you can book again whenever you\'re '
                  'ready.$keepsFreeSession',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Brand.red),
            child: Text(matched ? 'Cancel session' : 'Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.cancelRequest(request.id);
      await _load();
    } catch (e) {
      if (mounted) {
        _say(errorMessage(e, 'Couldn\'t cancel — check your connection.'));
      }
    }
  }

  Future<void> _pay(TherapyRequest request) async {
    setState(() => _paying = true);
    try {
      final outcome = await _payments.pay(request);
      if (!mounted) return;
      switch (outcome) {
        case SessionPaymentOutcome.paid:
          _say('Payment received — your session is confirmed.');
          await _load(quiet: true);
        case SessionPaymentOutcome.pendingVerification:
          _say('Your payment is going through. If the Join button doesn\'t '
              'unlock soon, tap "Already paid?".');
          await _load(quiet: true);
        case SessionPaymentOutcome.unavailable:
          _say('Paying in the app isn\'t available yet — we\'ll email you '
              'about payment.');
        case SessionPaymentOutcome.cancelled:
          break;
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is SessionAccessException
          ? e.message
          : purchaseErrorMessage(e);
      if (message != null) _say(message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _checkPayment(TherapyRequest request) async {
    setState(() => _paying = true);
    try {
      await _repo.confirmPayment(request.id);
      if (!mounted) return;
      _say('Payment found — you\'re all set.');
      await _load(quiet: true);
    } on SessionAccessException catch (e) {
      if (mounted) _say(e.message);
    } catch (e) {
      if (mounted) {
        _say(errorMessage(e, 'Couldn\'t check — try again in a moment.'));
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _join(TherapyRequest request) async {
    final therapist = _therapists[request.therapistId];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          counterpartName: therapist?.fullName ?? 'Your therapist',
          connect: () => _repo.joinSession(request.id),
        ),
      ),
    );
    if (mounted) await _load(quiet: true);
  }

  Future<void> _rate(TherapyRequest request) async {
    final therapist = _therapists[request.therapistId];
    final saved = await showSessionRatingSheet(
      context,
      title: 'How was your session?',
      subtitle: therapist == null
          ? 'Your rating helps us match people well.'
          : 'Your rating helps us match people well. ${therapist.firstName} '
              'never sees it on its own — only an average.',
      commentLabel: 'Anything you\'d like to tell us? (optional)',
      initialRating: _myRatings[request.id] ?? 0,
      onSubmit: (rating, comment) =>
          _repo.rateSession(request.id, rating: rating, comment: comment),
      describeError: (e) =>
          errorMessage(e, 'Couldn\'t send your rating — check your connection.'),
    );
    if (saved == true && mounted) {
      _say('Thank you — that helps.');
      await _load(quiet: true);
    }
  }

  Future<void> _showCompleted(TherapyRequest request) async {
    final therapist = _therapists[request.therapistId];
    final rating = _myRatings[request.id];
    final when = request.scheduledAt ?? request.createdAt;
    final wantsRating = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TherapistAvatar(
                    name: therapist?.fullName ?? request.topic,
                    photoUrl: therapist?.photoUrl,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          therapist?.fullName ?? request.topic,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Brand.ink,
                          ),
                        ),
                        Text(
                          formatDateTime(when),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Brand.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                therapist == null
                    ? 'Notes from your therapist'
                    : 'Notes from ${therapist.firstName}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Brand.ink,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                request.clientSummary ?? 'No notes for this session.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: request.clientSummary == null
                      ? Brand.textMuted
                      : Brand.ink,
                ),
              ),
              const SizedBox(height: 24),
              if (rating == null)
                ElevatedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Rate this session'),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'You rated it  ',
                      style: TextStyle(fontSize: 13.5, color: Brand.textMuted),
                    ),
                    StarRow(rating: rating.toDouble(), size: 18),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Change your rating'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (wantsRating == true && mounted) await _rate(request);
  }

  Widget _pill(String label,
      {required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? const Color(0x0A191919) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? Brand.ink : Brand.border,
          width: selected ? 1.6 : 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Brand.ink : Brand.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  /// Three steps, so nobody has to guess what happens after they tap.
  Widget _howItWorks() {
    const steps = [
      (
        Icons.tune_rounded,
        'Tell us what you need',
        'A topic and the times that suit you. Two taps.',
      ),
      (
        Icons.mark_email_read_rounded,
        'We match you',
        'A licensed therapist and a time, usually within a day.',
      ),
      (
        Icons.videocam_rounded,
        'You talk',
        'A private video call, right here in the app.',
      ),
    ];
    return Column(
      children: [
        for (final (index, (icon, title, detail)) in steps.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Brand.blue.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 15, color: Brand.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. $title',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Brand.textMuted,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The questions people actually have before they ask for help.
  Widget _reassurance() {
    const points = [
      (Icons.verified_user_rounded, 'Licensed therapists',
          'Qualified practitioners, not volunteers or chatbots.'),
      (Icons.lock_rounded, 'Private',
          'What you say in a session stays between you and them. Calls '
              'aren\'t recorded.'),
      (Icons.event_available_rounded, 'No commitment',
          'Book one session at a time. No subscription, nothing to cancel.'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x0A191919),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, (icon, title, detail)) in points.indexed)
            Padding(
              padding:
                  EdgeInsets.only(bottom: index == points.length - 1 ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: Brand.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Brand.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Brand.textMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _offerBanner({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String detail,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x0F3764CD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Brand.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bookingForm({required bool freeSession}) {
    final price = formatPrice(therapySessionPriceCents);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (freeSession)
          _offerBanner(
            icon: Icons.favorite_rounded,
            iconColor: Brand.red,
            title: 'Your first session is on us',
            detail: 'One full session with a licensed therapist, completely '
                'free — no card needed.',
          )
        else
          _offerBanner(
            icon: Icons.payments_outlined,
            iconColor: Brand.blue,
            title: 'Sessions are $price',
            detail: 'Your first one was on us. Once we\'ve matched you with '
                'a therapist, you pay in the app to confirm — no '
                'subscription.',
          ),
        const SizedBox(height: 26),
        const SectionHeader(title: 'What would you like to focus on?'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in therapyTopics)
              _pill(
                topic,
                selected: _topic == topic,
                onTap: () => setState(() => _topic = topic),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'When could you meet?'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in _timeSlots)
              _pill(
                slot,
                selected: _slots.contains(slot),
                onTap: () => setState(() {
                  _slots.contains(slot)
                      ? _slots.remove(slot)
                      : _slots.add(slot);
                }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Anything your therapist should know? (optional)',
            alignLabelWithHint: true,
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _topic == null || _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(freeSession
                  ? 'Request my free session'
                  : 'Request a session'),
        ),
        const SizedBox(height: 10),
        const Text(
          'We\'ll match you with a licensed therapist and a time, usually '
          'within a day, and email you when your session is booked.',
          style: TextStyle(fontSize: 12.5, color: Brand.textMuted, height: 1.5),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Brand.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Brand.ink,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _priceLine(TherapyRequest request) {
    if (request.isFreeSession) return 'First session — free';
    return switch (request.paymentStatus) {
      'paid' => '${request.priceLabel} — paid',
      'waived' => 'No charge for this session',
      _ when request.isPending =>
        '${request.priceLabel} — you\'ll pay once you\'re matched',
      _ => '${request.priceLabel} session',
    };
  }

  Widget _activeCard(TherapyRequest request) {
    final therapist = _therapists[request.therapistId];
    final confirmed = request.isConfirmed;
    final (title, detail) = !confirmed
        ? (
            'Request received',
            'We\'re finding the right licensed therapist for you — usually '
                'within a day. We\'ll email you when your session is booked.',
          )
        : request.needsPayment
            ? ('You\'re matched', 'Pay for your session to confirm your place.')
            : (
                'Session confirmed',
                'Everything\'s set. Join right here when it\'s time.',
              );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x0F3764CD),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: TherapyBookedArt(size: 84)),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 13,
              color: Brand.textMuted,
              height: 1.4,
            ),
          ),
          if (therapist != null) ...[
            const SizedBox(height: 14),
            TherapistCard(profile: therapist),
          ],
          const SizedBox(height: 6),
          if (confirmed && request.scheduledAt != null)
            _detailRow(
              Icons.schedule_rounded,
              '${formatDateTime(request.scheduledAt!)} · '
              '${request.durationMinutes} min',
            ),
          _detailRow(Icons.chat_bubble_outline_rounded, request.topic),
          if (!confirmed && request.availability.isNotEmpty)
            _detailRow(Icons.calendar_month_rounded,
                request.availability.join(' · ')),
          _detailRow(
            request.isFreeSession
                ? Icons.favorite_rounded
                : Icons.payments_outlined,
            _priceLine(request),
          ),
          if (confirmed && request.needsPayment) ...[
            const SizedBox(height: 16),
            _paymentBox(request),
          ],
          if (confirmed) ...[
            const SizedBox(height: 16),
            _joinSection(request),
          ],
          if (request.canCancelInApp) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancel(request),
                style: TextButton.styleFrom(foregroundColor: Brand.red),
                child: Text(confirmed ? 'Cancel session' : 'Cancel request'),
              ),
            ),
          ] else if (request.isActive) ...[
            const SizedBox(height: 12),
            const Text(
              'Need to cancel a paid session? Contact us from Settings and '
              'we\'ll sort out a refund.',
              style: TextStyle(fontSize: 12, color: Brand.textMuted, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentBox(TherapyRequest request) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${request.priceLabel} to confirm your session',
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pay securely in the app. The Join button unlocks as soon as '
            'it\'s paid.',
            style: TextStyle(fontSize: 12.5, color: Brand.textMuted, height: 1.45),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _paying ? null : () => _pay(request),
            child: _paying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text('Pay ${request.priceLabel}'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _paying ? null : () => _checkPayment(request),
            child: const Text('Already paid? Check again'),
          ),
        ],
      ),
    );
  }

  Widget _joinSection(TherapyRequest request) {
    final state = request.joinStateAt(_now());
    final ready = state == JoinState.open && !request.needsPayment;
    final hint = switch (state) {
      JoinState.tooEarly =>
        'The call opens 10 minutes before the start.',
      JoinState.over =>
        'This session\'s time has passed. If it didn\'t happen, contact us.',
      _ when request.needsPayment =>
        'The call opens once your session is paid for.',
      _ => 'Find a quiet, private spot — you\'ll need your camera and '
          'microphone.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: ready ? () => _join(request) : null,
          icon: const Icon(Icons.videocam_rounded),
          label: const Text('Join session'),
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: Brand.textMuted, height: 1.45),
        ),
      ],
    );
  }

  Widget _pastRow(TherapyRequest request) {
    final completed = request.isCompleted;
    final therapist = _therapists[request.therapistId];
    final rating = _myRatings[request.id];
    final when = request.scheduledAt ?? request.createdAt;
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
          onTap: completed ? () => _showCompleted(request) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.topic,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        therapist == null
                            ? formatDate(when)
                            : '${therapist.fullName} · ${formatDate(when)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Brand.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (!completed)
                  const Text(
                    'Cancelled',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Brand.textMuted,
                    ),
                  )
                else if (rating != null)
                  StarRow(rating: rating.toDouble())
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x143764CD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Rate',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Brand.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = _requests;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Talk to a therapist'),
        // The hero art carries the screen; a heavy bar above it competes.
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _failed
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Couldn\'t load — check your connection.',
                      style: TextStyle(fontSize: 14, color: Brand.textMuted),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            : requests == null
                ? const Center(child: CircularProgressIndicator())
                : _body(requests),
      ),
    );
  }

  Widget _body(List<TherapyRequest> requests) {
    final active = requests.where((r) => r.isActive).firstOrNull;
    final past = [...requests.where((r) => !r.isActive)];
    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        children: [
          const TherapyArt(height: 156),
          const SizedBox(height: 18),
          const Text(
            'You don\'t have to do this alone',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: PillarStripe()),
          const SizedBox(height: 16),
          const Text(
            'Private one-on-one sessions with licensed therapists, right '
            'from here. Tell us a little about what you need and we\'ll '
            'match you with the right person.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.6),
          ),
          const SizedBox(height: 24),
          if (active == null) ...[
            _howItWorks(),
            const SizedBox(height: 24),
          ],
          if (active != null)
            _activeCard(active)
          else
            _bookingForm(
              freeSession: _repo.isFreeSessionAvailable(requests),
            ),
          if (active == null) ...[
            const SizedBox(height: 24),
            _reassurance(),
          ],
          if (past.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionHeader(title: 'Past sessions'),
            const SizedBox(height: 12),
            for (final request in past) _pastRow(request),
          ],
          const SizedBox(height: 24),
          const CrisisFooter(
            trailing: ' This app can\'t replace emergency care.',
          ),
        ],
      ),
    );
  }
}
