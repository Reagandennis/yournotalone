import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../therapy/therapy_repository.dart';
import 'purchases_service.dart';

/// The Google Play one-time product a paid session is bought with: priced at
/// $20 in Play Console, a consumable in RevenueCat. Keep this in step with
/// THERAPY_SESSION_PRODUCT_ID in the confirm-session-payment Edge Function.
const therapySessionProductId = 'therapy';

enum SessionPaymentOutcome {
  /// The server has seen the payment; the session is paid.
  paid,

  /// The person backed out of the store sheet.
  cancelled,

  /// The store took the payment but the server hasn't seen it yet.
  /// "Check payment" on the session card checks again.
  pendingVerification,

  /// In-app payment isn't set up on this device or in the store yet.
  unavailable,
}

/// The store side of a session payment, so tests can stand in for
/// Google Play and RevenueCat.
abstract class SessionStore {
  /// False when in-app payment isn't set up on this device.
  bool get isAvailable;

  /// Ties the store customer to the signed-in user before buying.
  /// Throws when that can't be done (typically offline).
  Future<void> ensureIdentity(String userId);

  /// Buys one session. Returns false when the product isn't for sale.
  /// Throws a [PlatformException] when the store refuses, including when
  /// the person cancels.
  Future<bool> buy();
}

class RevenueCatSessionStore implements SessionStore {
  @override
  bool get isAvailable => PurchasesService.instance.isConfigured;

  @override
  Future<void> ensureIdentity(String userId) =>
      PurchasesService.instance.ensureIdentity(userId);

  @override
  Future<bool> buy() async {
    final List<StoreProduct> products;
    try {
      products = await Purchases.getProducts(
        [therapySessionProductId],
        productCategory: ProductCategory.nonSubscription,
      );
    } catch (e) {
      debugPrint('Session product lookup failed: $e');
      return false;
    }
    if (products.isEmpty) return false;
    await Purchases.purchase(PurchaseParams.storeProduct(products.first));
    return true;
  }
}

/// Paying for a session after the free first one.
///
/// The purchase goes through Google Play via RevenueCat, then the
/// confirm-session-payment Edge Function checks RevenueCat's record before
/// marking the session paid. The app never marks a session paid itself.
class SessionPayments {
  SessionPayments({
    TherapyRepository? repository,
    SessionStore? store,
    String? Function()? currentUserId,
    Future<void> Function(Duration)? wait,
  })  : _repository = repository ?? TherapyRepository(),
        _store = store ?? RevenueCatSessionStore(),
        _currentUserId = currentUserId ?? _supabaseUserId,
        _wait = wait ?? _realWait;

  final TherapyRepository _repository;
  final SessionStore _store;
  final String? Function() _currentUserId;

  /// Injectable so tests don't sit through the retry back-off.
  final Future<void> Function(Duration) _wait;

  static Future<void> _realWait(Duration d) => Future<void>.delayed(d);

  static String? _supabaseUserId() =>
      Supabase.instance.client.auth.currentUser?.id;

  Future<SessionPaymentOutcome> pay(TherapyRequest request) async {
    if (!_store.isAvailable) return SessionPaymentOutcome.unavailable;

    // The server looks purchases up by Supabase user id, so the store
    // customer has to be that user before any money moves. Without this a
    // purchase made while RevenueCat still held an anonymous id (identity
    // sync missed, e.g. an offline launch) is never found.
    final userId = _currentUserId();
    if (userId == null) throw const SessionAccessException('invalid_token');
    await _store.ensureIdentity(userId);

    // A purchase from an earlier attempt may already be waiting: the app
    // closed mid-way, or "pending verification" and a second tap. Use it
    // rather than charging again.
    if (await _confirm(request)) return SessionPaymentOutcome.paid;

    try {
      if (!await _store.buy()) return SessionPaymentOutcome.unavailable;
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return SessionPaymentOutcome.cancelled;
      }
      rethrow;
    }

    // The store has the payment; RevenueCat can take a moment to record it.
    for (var attempt = 1; attempt <= 3; attempt++) {
      if (await _confirm(request)) return SessionPaymentOutcome.paid;
      await _wait(Duration(seconds: 2 * attempt));
    }
    return SessionPaymentOutcome.pendingVerification;
  }

  /// True once the server has attached a purchase to [request]; false when
  /// it has none to attach. Anything else (offline, not configured) throws,
  /// since buying would be pointless until it's sorted.
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
