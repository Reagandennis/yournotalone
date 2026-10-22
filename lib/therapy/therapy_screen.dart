import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../billing/session_payments.dart';
import '../brand.dart';
import '../brand_layout.dart';
import '../home/home_ui.dart';
import '../notifications/notification_permission.dart';
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

/// Talk to a real therapist: pay for and request a private session, see
/// who you've been matched with and when, join the video call, and rate it
/// afterwards. Nothing reaches the care team until the session is paid
/// for, so therapists are only booked by people who've committed.
class TherapyScreen extends StatefulWidget {
  const TherapyScreen({
    super.key,
    this.repository,
    this.payments,
    this.notifications,
    this.clock,
  });

  /// Injectable so the booking flow can be exercised without a backend.
  final TherapyRepository? repository;
  final SessionPayments? payments;
  final NotificationPermission? notifications;

  /// Injectable so tests can put "now" anywhere around a session.
  final DateTime Function()? clock;

  static const routeName = '/therapy';

  /// The route every caller pushes, named so a notification tap can find
  /// the screen if it's already open instead of stacking another.
  static Route<void> route() => MaterialPageRoute(
        settings: const RouteSettings(name: routeName),
        builder: (_) => const TherapyScreen(),
      );

  @override
  State<TherapyScreen> createState() => _TherapyScreenState();
}

class _TherapyScreenState extends State<TherapyScreen> {
  late final _repo = widget.repository ?? TherapyRepository();
  late final _payments =
      widget.payments ?? SessionPayments(repository: _repo);
  late final _notifications =
      widget.notifications ?? NotificationPermission.instance;
  final _noteController = TextEditingController();

  /// Whether the phone will show our notifications. While a session is on
  /// the way and this is false, the card says so.
  bool _notificationsOn = true;

  List<TherapyRequest>? _requests;
  Map<String, TherapistProfile> _therapists = const {};
  Map<String, int> _myRatings = const {};
  bool _failed = false;
  String? _topic;
  final _slots = <String>{};
  bool _submitting = false;
  bool _paying = false;

  /// Sessions whose Paystack payment went through but the server hasn't seen
  /// yet. Their card offers "Check payment" instead of "Pay", so a slow
  /// RevenueCat record can't be paid for twice.
  final _awaitingVerification = <String>{};

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
      final notificationsOn = await _notifications.isEnabled();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _therapists = therapists;
        _myRatings = ratings;
        _notificationsOn = notificationsOn;
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

  /// Saves the request as a draft and goes straight to Paystack. The
  /// draft stays on screen (with Pay and Check payment) if the payment
  /// doesn't settle there and then; leaving the checkout discards it
  /// and leaves the form as it was.
  Future<void> _submit() async {
    final topic = _topic;
    if (topic == null) return;
    setState(() => _submitting = true);
    try {
      final draft = await _repo.requestSession(
        topic: topic,
        availability: [
          for (final slot in _timeSlots)
            if (_slots.contains(slot)) slot,
        ],
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      // An account the care team has waived the fee for: the request is
      // already with them, so there's nothing to pay (migration 0023).
      final outcome = draft.needsPayment
          ? await _pay(draft, fromForm: true)
          : SessionPaymentOutcome.paid;
      if (!draft.needsPayment) {
        _say('Your request is with our care team — there\'s no charge for '
            'your sessions.');
      }
      if (!mounted) return;
      switch (outcome) {
        case SessionPaymentOutcome.paid:
          _topic = null;
          _slots.clear();
          _noteController.clear();
          // Notifications are how they'll hear about the match and the
          // reminder, so this is the moment to make sure they can arrive.
          await _ensureNotifications();
          await _load();
        case SessionPaymentOutcome.cancelled:
        case SessionPaymentOutcome.unavailable:
          // Nothing was paid, so there's nothing to keep.
          await _discardQuietly(draft);
        case SessionPaymentOutcome.pendingVerification:
        case null:
          // Paystack may have taken the money: keep the draft so the
          // payment can be attached to it.
          await _load(quiet: true);
      }
    } catch (e) {
      if (!mounted) return;
      if (e is PostgrestException && e.code == '23514') {
        // A size check: the form caps the note itself, so this is a
        // stale build or something that isn't the app.
        _say('That note is too long — please keep it under 1000 characters.');
      } else if (e is PostgrestException &&
          e.code == 'P0001' &&
          e.message.isNotEmpty) {
        // The database refused with a reason written for people — a
        // request already open, or too many in a day.
        _say(e.message);
        // If it's an open request we hadn't seen, show it instead of the form.
        await _load(quiet: true);
      } else {
        _say(errorMessage(
            e, 'Couldn\'t send your request — check your connection.'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Asks for notification permission if we never have, or shows where to
  /// turn it on if it was refused — then starts watching for session news.
  Future<void> _ensureNotifications() async {
    final on = await _notifications.ensure(
      context,
      reason: NotificationReasons.session,
    );
    unawaited(SessionNotifications.instance.start());
    if (mounted) setState(() => _notificationsOn = on);
  }

  /// Drops a draft nobody paid for, without ceremony.
  Future<void> _discardQuietly(TherapyRequest draft) async {
    try {
      await _repo.cancelRequest(draft.id);
    } catch (_) {
      // The sweep cancels unpaid drafts after a day anyway.
    }
    if (mounted) await _load(quiet: true);
  }

  Future<void> _cancel(TherapyRequest request) async {
    final (title, body, action) = request.isAwaitingPayment
        ? (
            'Discard this request?',
            'Nothing has been paid, so there\'s nothing to refund. You can '
                'start again whenever you like.',
            'Discard',
          )
        : request.isConfirmed
            ? (
                'Cancel this session?',
                'We\'ll let your therapist know and refund your '
                    '${request.priceLabel} in full, since it\'s more than 24 '
                    'hours away. You can book again whenever you\'re ready.',
                'Cancel session',
              )
            : (
                'Cancel this request?',
                'We haven\'t matched you yet, so your ${request.priceLabel} '
                    'is refunded in full. You can book again whenever '
                    'you\'re ready.',
                'Cancel request',
              );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.brand.red),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.cancelRequest(request.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      if (e is PostgrestException && e.code == 'P0001' && e.message.isNotEmpty) {
        // The session started while this screen was open, so the database
        // said no in plain words.
        _say(e.message);
        await _load(quiet: true);
      } else {
        _say(errorMessage(e, 'Couldn\'t cancel — check your connection.'));
      }
    }
  }

  /// Takes the payment for [request]. Returns the outcome, or null when
  /// the attempt failed before an outcome was known. [fromForm] leaves
  /// the reload to the caller.
  Future<SessionPaymentOutcome?> _pay(
    TherapyRequest request, {
    bool fromForm = false,
  }) async {
    setState(() => _paying = true);
    try {
      final outcome =
          await _payments.pay(request, waitForCheckout: _waitForCheckout);
      if (!mounted) return outcome;
      switch (outcome) {
        case SessionPaymentOutcome.paid:
          _say(request.isAwaitingPayment
              ? 'Payment received — your request is with our care team and '
                  'your receipt is on its way by email.'
              : 'Payment received — your receipt is on its way by email.');
          if (!fromForm) await _load(quiet: true);
        case SessionPaymentOutcome.pendingVerification:
          _awaitingVerification.add(request.id);
          _say('Your payment is going through. If it isn\'t confirmed in a '
              'minute, tap "Check payment".');
          if (!fromForm) await _load(quiet: true);
        case SessionPaymentOutcome.unavailable:
          _say('We couldn\'t open the payment page on this device — please '
              'try again later.');
        case SessionPaymentOutcome.cancelled:
          break;
      }
      return outcome;
    } catch (e) {
      if (!mounted) return null;
      final message = e is SessionAccessException
          ? e.message
          : errorMessage(e, 'The payment didn\'t go through. Please try again.');
      _say(message);
      return null;
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Shown over the screen while Paystack's page is open, until the
  /// payment is found or the person gives up.
  Future<bool> _waitForCheckout(Future<bool> Function() checkPaid) async {
    final paid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutWaitDialog(checkPaid: checkPaid),
    );
    return paid ?? false;
  }

  Future<void> _checkPayment(TherapyRequest request) async {
    setState(() => _paying = true);
    try {
      await _repo.confirmPayment(request.id);
      if (!mounted) return;
      _awaitingVerification.remove(request.id);
      _say(request.isAwaitingPayment
          ? 'Payment found — your request is with our care team.'
          : 'Payment found — you\'re all set.');
      await _load(quiet: true);
    } on SessionAccessException catch (e) {
      // The server has looked and there's nothing to attach, so paying is
      // back on the table.
      if (e.code == 'no_payment_found') _awaitingVerification.remove(request.id);
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
        settings: const RouteSettings(name: CallScreen.routeName),
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
    final c = context.brand;
    final therapist = _therapists[request.therapistId];
    final rating = _myRatings[request.id];
    final when = request.scheduledAt ?? request.createdAt;
    final wantsRating = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                        Text(
                          formatDateTime(when),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.textMuted,
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                request.clientSummary ?? 'No notes for this session.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: request.clientSummary == null
                      ? c.textMuted
                      : c.ink,
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
                    Text(
                      'You rated it  ',
                      style: TextStyle(fontSize: 13.5, color: c.textMuted),
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
    final c = context.brand;
    return Material(
      color: selected ? c.tint(Pillars.black, 0.04) : c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? c.ink : c.border,
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
              color: selected ? c.ink : c.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  /// Three steps, so nobody has to guess what happens after they tap.
  Widget _howItWorks() {
    final c = context.brand;
    const steps = [
      (
        Icons.tune_rounded,
        'Tell us what you need, and pay',
        'A topic, the times that suit you, and \$20 — paid securely in '
            'the app. Nothing is sent until it\'s paid.',
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
                          color: c.tint(Pillars.blue, 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 15, color: c.blue),
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
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textMuted,
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
    final c = context.brand;
    const points = [
      (Icons.verified_user_rounded, 'Licensed therapists',
          'Qualified practitioners, not volunteers or chatbots.'),
      (Icons.lock_rounded, 'Private',
          'What you say in a session stays between you and them. Calls '
              'aren\'t recorded.'),
      (Icons.event_available_rounded, 'One session at a time',
          'No subscription. Cancel up to 24 hours before for a full '
              'refund — after that, or if you don\'t join, the session isn\'t '
              'refunded.'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.tint(Pillars.black, 0.04),
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
                  Icon(icon, size: 18, color: c.ink),
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
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.textMuted,
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
    final c = context.brand;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.tint(Pillars.blue, 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.chip,
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textMuted,
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

  Widget _bookingForm() {
    final c = context.brand;
    final price = formatPrice(therapySessionPriceCents);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _offerBanner(
          icon: Icons.payments_outlined,
          iconColor: c.blue,
          title: 'Sessions are $price, paid when you book',
          detail: 'Pay securely by $therapyPaymentMethods through Paystack '
              '(charged as $therapySessionChargeLabel) and your request goes '
              'straight to our care team. You get a receipt by email. No '
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
              : Text('Pay $price and request a session'),
        ),
        const SizedBox(height: 10),
        Text(
          'We\'ll match you with a licensed therapist and a time, usually '
          'within a day, and email you when your session is booked. '
          '$therapyCancellationPolicy',
          style: TextStyle(fontSize: 12.5, color: c.textMuted, height: 1.5),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String text) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: c.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: c.ink,
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
      'paid' => '${request.priceLabel} — paid, receipt emailed',
      'waived' => 'No charge for this session',
      _ when request.isAwaitingPayment =>
        '${request.priceLabel} — pay to send your request',
      _ => '${request.priceLabel} — payment needed',
    };
  }

  Widget _activeCard(TherapyRequest request) {
    final c = context.brand;
    final therapist = _therapists[request.therapistId];
    final confirmed = request.isConfirmed;
    final (title, detail) = request.isAwaitingPayment
        ? (
            'Almost there',
            'Your request is saved but hasn\'t reached our care team yet. '
                'It\'s sent the moment your session is paid for.',
          )
        : !confirmed
            ? (
                'Request received',
                'We\'re finding the right licensed therapist for you — '
                    'usually within a day. We\'ll email you when your '
                    'session is booked.',
              )
            : request.needsPayment
                ? (
                    'You\'re matched',
                    'Pay for your session to confirm your place.',
                  )
                : (
                    'Session confirmed',
                    'Everything\'s set. Join right here when it\'s time.',
                  );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.tint(Pillars.blue, 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: TherapyBookedArt(size: 84)),
          const SizedBox(height: 14),
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
            detail,
            style: TextStyle(
              fontSize: 13,
              color: c.textMuted,
              height: 1.4,
            ),
          ),
          if (request.isActive && !_notificationsOn) ...[
            const SizedBox(height: 14),
            NotificationsOffBanner(
              message: confirmed
                  ? 'Notifications are off, so you won\'t get the ten-minute '
                      'reminder for this session.'
                  : 'Notifications are off, so you won\'t hear when you\'re '
                      'matched.',
              reason: NotificationReasons.session,
              permission: _notifications,
              onChanged: (on) {
                if (mounted) setState(() => _notificationsOn = on);
              },
            ),
          ],
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
          // Once the call window has closed there's nothing left to pay for:
          // the server cancels an unpaid session within a couple of hours.
          if (request.needsPayment && !request.hasElapsedAt(_now())) ...[
            const SizedBox(height: 16),
            _paymentBox(request),
          ],
          if (confirmed) ...[
            const SizedBox(height: 16),
            _joinSection(request),
          ],
          if (request.canCancelAt(_now())) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _cancel(request),
                style: TextButton.styleFrom(foregroundColor: c.red),
                child: Text(request.isAwaitingPayment
                    ? 'Discard'
                    : confirmed
                        ? 'Cancel session'
                        : 'Cancel request'),
              ),
            ),
          ] else if (request.isActive) ...[
            const SizedBox(height: 12),
            Text(
              'Your session is less than 24 hours away, so it can no longer '
              'be cancelled here. If you can\'t make it, reply to your booking '
              'email — a missed or late-cancelled session isn\'t refunded.',
              style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentBox(TherapyRequest request) {
    final c = context.brand;
    final awaiting = _awaitingVerification.contains(request.id);
    final spinner = const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            awaiting
                ? 'Your payment is being verified'
                : request.isAwaitingPayment
                    ? '${request.priceLabel} to send your request'
                    : '${request.priceLabel} to confirm your session',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            awaiting
                ? 'Paystack has your payment. Don\'t pay again — your '
                    'request goes through as soon as it\'s found.'
                : request.isAwaitingPayment
                    ? 'Pay securely by $therapyPaymentMethods through '
                        'Paystack (charged as $therapySessionChargeLabel) '
                        'and your request goes '
                        'straight to our care team, with a receipt by '
                        'email. $therapyCancellationPolicy'
                    : 'Pay securely by $therapyPaymentMethods through '
                        'Paystack (charged as $therapySessionChargeLabel). '
                        'The Join button unlocks as '
                        'soon as it\'s paid.',
            style: TextStyle(
              fontSize: 12.5,
              color: c.textMuted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (awaiting)
            ElevatedButton(
              onPressed: _paying ? null : () => _checkPayment(request),
              child: _paying ? spinner : const Text('Check payment'),
            )
          else ...[
            ElevatedButton(
              onPressed: _paying ? null : () => _pay(request),
              child: _paying ? spinner : Text('Pay ${request.priceLabel}'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _paying ? null : () => _checkPayment(request),
              child: const Text('Already paid? Check again'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _joinSection(TherapyRequest request) {
    final c = context.brand;
    final state = request.joinStateAt(_now());
    final ready = state == JoinState.open && !request.needsPayment;
    final hint = switch (state) {
      JoinState.tooEarly =>
        'The call opens 10 minutes before the start.',
      JoinState.over when request.needsPayment =>
        'This session\'s time has passed without payment. It\'ll be '
            'cancelled shortly, and you can book again after that.',
      JoinState.over =>
        'This session\'s time has passed. It closes out on its own within '
            'a couple of hours: if it went ahead, any note from your '
            'therapist appears under Past sessions; if it didn\'t happen, '
            'you\'ll be able to book again.',
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
          style: TextStyle(fontSize: 12.5, color: c.textMuted, height: 1.45),
        ),
      ],
    );
  }

  Widget _pastRow(TherapyRequest request) {
    final c = context.brand;
    // A missed session has no note to read and nothing fair to rate.
    final completed = request.isCompleted && !request.wasMissed;
    final therapist = _therapists[request.therapistId];
    final rating = _myRatings[request.id];
    final when = request.scheduledAt ?? request.createdAt;
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        therapist == null
                            ? formatDate(when)
                            : '${therapist.fullName} · ${formatDate(when)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (!completed)
                  Text(
                    sessionOutcomeLabel(request),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: c.textMuted,
                    ),
                  )
                else if (rating != null)
                  StarRow(rating: rating.toDouble())
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.tint(Pillars.blue, 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Rate',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.blue,
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
    final c = context.brand;
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
                    Text(
                      'Couldn\'t load — check your connection.',
                      style: TextStyle(fontSize: 14, color: c.textMuted),
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
                : ReadableWidth(child: _body(requests)),
      ),
    );
  }

  Widget _body(List<TherapyRequest> requests) {
    final c = context.brand;
    final active = requests.where((r) => r.isCurrent).firstOrNull;
    // A draft that was discarded or expired never went anywhere; listing
    // it as a past session would only puzzle people.
    final past = [
      ...requests.where((r) => !r.isCurrent && r.submittedAt != null),
    ];
    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
        children: [
          const TherapyArt(height: 156),
          const SizedBox(height: 18),
          Text(
            'You don\'t have to do this alone',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: c.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: PillarStripe()),
          const SizedBox(height: 16),
          Text(
            'Private one-on-one sessions with licensed therapists, right '
            'from here. Tell us a little about what you need and we\'ll '
            'match you with the right person.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.6),
          ),
          const SizedBox(height: 24),
          if (active == null) ...[
            _howItWorks(),
            const SizedBox(height: 24),
          ],
          if (active != null) _activeCard(active) else _bookingForm(),
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

/// While Paystack's page is open: checks for the payment every few seconds
/// and as soon as the app comes back to the front, and closes itself once
/// it's found. "Cancel" gives up; the draft is discarded only if one last
/// check still finds nothing.
class _CheckoutWaitDialog extends StatefulWidget {
  const _CheckoutWaitDialog({required this.checkPaid});

  final Future<bool> Function() checkPaid;

  @override
  State<_CheckoutWaitDialog> createState() => _CheckoutWaitDialogState();
}

class _CheckoutWaitDialogState extends State<_CheckoutWaitDialog> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;
  bool _checking = false;
  bool _notFoundYet = false;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _check());
    _lifecycle = AppLifecycleListener(onResume: _check);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check({bool asked = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final paid = await widget.checkPaid();
      if (!mounted) return;
      if (paid) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _offline = false;
        if (asked) _notFoundYet = true;
      });
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final hint = _offline
        ? 'We can\'t reach our server right now — we\'ll keep checking.'
        : _notFoundYet
            ? 'We haven\'t seen your payment yet. If you\'ve just paid, give '
                'it a few seconds.'
            : 'Finish paying on the Paystack page — by '
                '$therapyPaymentMethods. This closes by itself once your '
                'payment is in.';
    return AlertDialog(
      title: const Text('Waiting for your payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            hint,
            style: TextStyle(fontSize: 13.5, color: c.textMuted, height: 1.45),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _checking ? null : () => _check(asked: true),
          child: const Text('I\'ve paid'),
        ),
      ],
    );
  }
}
