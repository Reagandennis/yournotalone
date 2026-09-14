import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

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
  /// "Already paid?" on the session card checks again.
  pendingVerification,

  /// In-app payment isn't set up on this device or in the store yet.
  unavailable,
}

/// Paying for a session after the free first one.
///
/// The purchase goes through Google Play via RevenueCat, then the
/// confirm-session-payment Edge Function checks RevenueCat's record before
/// marking the session paid. The app never marks a session paid itself.
class SessionPayments {
  SessionPayments({TherapyRepository? repository})
      : _repository = repository ?? TherapyRepository();

  final TherapyRepository _repository;

  Future<SessionPaymentOutcome> pay(TherapyRequest request) async {
    if (!PurchasesService.instance.isConfigured) {
      return SessionPaymentOutcome.unavailable;
    }

    final List<StoreProduct> products;
    try {
      products = await Purchases.getProducts(
        [therapySessionProductId],
        productCategory: ProductCategory.nonSubscription,
      );
    } catch (e) {
      debugPrint('Session product lookup failed: $e');
      return SessionPaymentOutcome.unavailable;
    }
    if (products.isEmpty) return SessionPaymentOutcome.unavailable;

    try {
      await Purchases.purchase(PurchaseParams.storeProduct(products.first));
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return SessionPaymentOutcome.cancelled;
      }
      rethrow;
    }

    // The store has the payment; RevenueCat can take a moment to record it.
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _repository.confirmPayment(request.id);
        return SessionPaymentOutcome.paid;
      } on SessionAccessException catch (e) {
        if (e.code != 'no_payment_found') rethrow;
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
    }
    return SessionPaymentOutcome.pendingVerification;
  }
}
