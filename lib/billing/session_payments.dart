import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../therapy/therapy_repository.dart';

enum SessionPaymentOutcome {
  /// The server has seen the payment; the session is paid.
  paid,

  /// The person left the checkout without paying.
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
  })  : _repository = repository ?? TherapyRepository(),
        _browser = browser ?? InAppCheckoutBrowser(),
        _currentUserId = currentUserId ?? _supabaseUserId,
        _wait = wait ?? _realWait;

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

    final url = await _repository.startCheckout(request.id);
    if (url == null) return SessionPaymentOutcome.paid;
    if (!await _browser.open(url)) return SessionPaymentOutcome.unavailable;

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

  /// True once the server has attached a payment to [request]; false when
  /// it has none to attach. Anything else (offline, not configured) throws,
  /// since opening a checkout would be pointless until it's sorted.
  Future<bool> _confirm(TherapyRequest request) async {
    try {
      await _repository.confirmPayment(request.id);
      return true;
    } on SessionAccessException catch (e) {
      if (e.code != 'no_payment_found') rethrow;
      return false;
    }
  }
}
