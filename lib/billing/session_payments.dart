import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../therapy/therapy_repository.dart';

enum SessionPaymentOutcome {
  /// The server has seen the payment; the session is paid.
  paid,

  /// The person left the checkout before a payment was seen. That isn't
  /// proof nothing will be paid: an M-Pesa prompt can be approved on the
  /// phone minutes later. [SessionPayments.pending] remembers the checkout,
  /// so the card offers "Check payment" rather than a second charge.
  cancelled,

  /// Kept for callers that still handle it: the payment may have gone
  /// through but the server hasn't seen it yet. "Check payment" on the
  /// session card checks again.
  pendingVerification,

  /// The checkout page couldn't be opened on this device.
  unavailable,
}

/// Shows whatever the person sees while the Paystack page is open, until
/// [checkPaid] reports the payment (true) or they give up (false).
/// [checkPaid] asks the server; it throws when the server can't be reached.
typedef CheckoutWaiter = Future<bool> Function(
  Future<bool> Function() checkPaid,
);

/// Where the Paystack checkout page is shown, so tests can stand in for
/// the browser.
abstract class CheckoutBrowser {
  /// Opens [url]. False when nothing on the device could show it.
  Future<bool> open(Uri url);

  /// Closes the page if the platform lets the app do that.
  Future<void> close();
}

/// Paystack's page in an in-app browser: Safari View Controller on iOS
/// (where Apple Pay works) and a Custom Tab on Android.
class InAppCheckoutBrowser implements CheckoutBrowser {
  static const _mode = LaunchMode.inAppBrowserView;

  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(url, mode: _mode);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> close() async {
    try {
      if (await supportsCloseForLaunchMode(_mode)) await closeInAppWebView();
    } catch (_) {
      // Nothing open, or the platform can't close it; the person can.
    }
  }
}

/// Checkouts opened recently, kept on this device by request id so they
/// survive the app being closed: for [window] after one is opened, the
/// session card offers "Check payment" instead of "Pay", because a payment
/// (an M-Pesa prompt above all) can still land after the page was closed,
/// and paying again would charge twice.
class PendingCheckouts {
  PendingCheckouts({
    DateTime Function()? clock,
    this.window = const Duration(minutes: 10),
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// How long after a checkout opened its payment is still waited for.
  final Duration window;

  static const _prefix = 'therapy.checkout_opened.';

  DateTime now() => _clock();

  /// Notes that a checkout for [requestId] was opened [at] (just now
  /// unless given: the server says when one still in progress was opened).
  /// Never fails.
  Future<void> mark(String requestId, {DateTime? at}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        '$_prefix$requestId',
        (at ?? _clock()).millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Couldn\'t note the checkout: $e');
    }
  }

  /// Forgets [requestId]'s checkout: it was paid, or the server has looked
  /// and found nothing. Never fails.
  Future<void> clear(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$requestId');
    } catch (e) {
      debugPrint('Couldn\'t clear the checkout: $e');
    }
  }

  /// Whether a checkout opened at [openedAt] is still within [window].
  bool isFresh(DateTime openedAt) {
    final age = _clock().difference(openedAt);
    return age < window && !age.isNegative;
  }

  /// When each of [requestIds] had a checkout opened, for those still
  /// within [window]. Older notes are dropped. Never fails: without
  /// storage, nothing is pending.
  Future<Map<String, DateTime>> openedAmong(Iterable<String> requestIds) async {
    final found = <String, DateTime>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final id in requestIds) {
        final ms = prefs.getInt('$_prefix$id');
        if (ms == null) continue;
        final at = DateTime.fromMillisecondsSinceEpoch(ms);
        if (isFresh(at)) {
          found[id] = at;
        } else {
          await prefs.remove('$_prefix$id');
        }
      }
    } catch (e) {
      debugPrint('Checkouts unavailable: $e');
    }
    return found;
  }
}

/// Paying for a session through Paystack (card, M-Pesa, Apple Pay).
///
/// The paystack-payment Edge Function opens the checkout and, afterwards,
/// asks Paystack whether it was paid before marking the session paid. The
/// app never marks a session paid itself.
class SessionPayments {
  SessionPayments({
    TherapyRepository? repository,
    CheckoutBrowser? browser,
    String? Function()? currentUserId,
    Future<void> Function(Duration)? wait,
    PendingCheckouts? pending,
  })  : _repository = repository ?? TherapyRepository(),
        _browser = browser ?? InAppCheckoutBrowser(),
        _currentUserId = currentUserId ?? _supabaseUserId,
        _wait = wait ?? _realWait,
        pending = pending ?? PendingCheckouts();

  /// Checkouts opened in the last few minutes whose payment may yet land.
  final PendingCheckouts pending;

  final TherapyRepository _repository;
  final CheckoutBrowser _browser;
  final String? Function() _currentUserId;

  /// Injectable so tests don't sit through the polling interval.
  final Future<void> Function(Duration) _wait;

  static Future<void> _realWait(Duration d) => Future<void>.delayed(d);

  static String? _supabaseUserId() =>
      Supabase.instance.client.auth.currentUser?.id;

  /// Takes the payment for [request]. [waitForCheckout] is shown while the
  /// Paystack page is open; without one the server is polled for up to
  /// ten minutes.
  Future<SessionPaymentOutcome> pay(
    TherapyRequest request, {
    CheckoutWaiter? waitForCheckout,
  }) async {
    if (_currentUserId() == null) {
      throw const SessionAccessException('invalid_token');
    }

    // A checkout from an earlier attempt may already be paid: the app
    // closed mid-way, or a second tap. Use it rather than charging again.
    if (await _confirm(request)) return SessionPaymentOutcome.paid;

    final Uri? url;
    try {
      url = await _repository.startCheckout(request.id);
    } on SessionAccessException catch (e) {
      // The server won't open another checkout while the last one may
      // still be paid (HTTP 409): wait for that one instead.
      if (e.code == 'payment_in_progress') {
        await pending.mark(request.id, at: e.openedAt);
      }
      rethrow;
    }
    if (url == null) {
      await pending.clear(request.id);
      return SessionPaymentOutcome.paid;
    }
    if (!await _browser.open(url)) return SessionPaymentOutcome.unavailable;
    // Noted before waiting, so a payment that lands after the app was
    // closed mid-checkout isn't paid for again on the next start.
    await pending.mark(request.id);

    final bool paid;
    try {
      paid = await (waitForCheckout ?? _poll)(() => _confirm(request));
    } finally {
      await _browser.close();
    }
    if (paid) return SessionPaymentOutcome.paid;

    // One last look, in case they paid just as they closed the page.
    return await _confirm(request)
        ? SessionPaymentOutcome.paid
        : SessionPaymentOutcome.cancelled;
  }

  Future<bool> _poll(Future<bool> Function() checkPaid) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      await _wait(const Duration(seconds: 3));
      if (await checkPaid()) return true;
    }
    return false;
  }

  /// Whether a payment has reached [request] (attaching it if one has).
  /// For a last look before a draft is thrown away: an M-Pesa prompt can be
  /// approved minutes after the checkout page closed. Throws when it can't
  /// tell (offline), and with `payment_in_progress` when nothing is paid yet
  /// but a checkout may still be (the draft must stay for it).
  Future<bool> isPaid(TherapyRequest request) =>
      _confirm(request, inProgressThrows: true);

  /// True once the server has attached a payment to [request]; false when
  /// it has none to attach, or none yet while a checkout may still be paid
  /// (`payment_in_progress`: its note is kept, so "Pay" stays away). Anything
  /// else (offline, not configured) throws, since opening a checkout would
  /// be pointless until it's sorted.
  Future<bool> _confirm(
    TherapyRequest request, {
    bool inProgressThrows = false,
  }) async {
    try {
      await _repository.confirmPayment(request.id);
      await pending.clear(request.id);
      return true;
    } on SessionAccessException catch (e) {
      if (e.code == 'payment_in_progress' && !inProgressThrows) return false;
      if (e.code != 'no_payment_found') rethrow;
      return false;
    }
  }
}
