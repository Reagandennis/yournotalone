import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'trial_reminder.dart';

/// Must match the entitlement identifier in the RevenueCat dashboard.
const proEntitlementId = 'Techgetafrica Pro';

/// RevenueCat public API key for the Play Store app.
const _googlePlayApiKey = 'goog_HcusldvsINIxkCHNpcprsTVSNdw';

/// RevenueCat Test Store key — still used on iOS/macOS until the App
/// Store app is configured (swap in the appl_… key then).
const _testStoreApiKey = 'test_LIOnFYhIcjvbOTTSrOhveSnxroM';

String get _revenueCatApiKey =>
    Platform.isAndroid ? _googlePlayApiKey : _testStoreApiKey;

/// App-wide RevenueCat wrapper: configures the SDK, keeps the RevenueCat
/// identity in step with the Supabase account, and exposes entitlement
/// state plus purchase/restore/paywall/customer-center actions.
class PurchasesService {
  PurchasesService._();

  static final PurchasesService instance = PurchasesService._();

  /// Live entitlement state; true while "Techgetafrica Pro" is active.
  final ValueNotifier<bool> isPro = ValueNotifier(false);

  bool _configured = false;

  bool get isConfigured => _configured;

  static bool get _supported =>
      !kIsWeb &&
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  /// Call once at startup, after Supabase is initialized.
  Future<void> init() async {
    if (!_supported || _configured) return;
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      final configuration = PurchasesConfiguration(_revenueCatApiKey)
        // Tie purchases to the Supabase account so premium follows the
        // user across devices and reinstalls.
        ..appUserID = Supabase.instance.client.auth.currentUser?.id;
      await Purchases.configure(configuration);
      _configured = true;
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
      // Attach the identity listener before anything that needs the network:
      // with no cached customer info and no connection, getCustomerInfo
      // throws, and a listener attached after it would never be attached.
      _syncIdentityWithAuth();
    } catch (e) {
      debugPrint('RevenueCat configure failed: $e');
      return;
    }
    try {
      _onCustomerInfo(await Purchases.getCustomerInfo());
    } catch (e) {
      // Offline with nothing cached; the update listener fills this in
      // once RevenueCat is reachable.
      debugPrint('RevenueCat customer info unavailable: $e');
    }
  }

  /// Makes RevenueCat's current customer the signed-in Supabase user
  /// [userId], so a purchase is recorded against the customer the server
  /// looks up. Throws when RevenueCat can't switch (typically offline).
  Future<void> ensureIdentity(String userId) async {
    if (await Purchases.appUserID == userId) return;
    final result = await Purchases.logIn(userId);
    _onCustomerInfo(result.customerInfo);
  }

  /// Log in/out of RevenueCat whenever the Supabase session changes.
  void _syncIdentityWithAuth() {
    Supabase.instance.client.auth.onAuthStateChange.listen((state) async {
      final user = state.session?.user;
      try {
        if (user != null) {
          final result = await Purchases.logIn(user.id);
          _onCustomerInfo(result.customerInfo);
        } else if (!await Purchases.isAnonymous) {
          final info = await Purchases.logOut();
          _onCustomerInfo(info);
        }
      } catch (e) {
        debugPrint('RevenueCat identity sync failed: $e');
      }
    });
  }

  void _onCustomerInfo(CustomerInfo info) {
    final pro = info.entitlements.active[proEntitlementId];
    isPro.value = pro != null;
    // The paywall promises a reminder before a trial turns into a charge.
    unawaited(TrialReminder.sync(pro));
  }

  /// Asks RevenueCat afresh whether the signed-in account has Pro, after
  /// making sure it is looking at that account. On a device someone has
  /// just signed in to, the identity switch in [_syncIdentityWithAuth] may
  /// still be in flight — or have failed offline — by the time a screen
  /// wants to sell them something they already pay for. Returns the
  /// entitlement state; never throws.
  Future<bool> refreshEntitlement() async {
    if (!_configured) return isPro.value;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) await ensureIdentity(userId);
      _onCustomerInfo(await Purchases.getCustomerInfo());
    } catch (e) {
      debugPrint('RevenueCat entitlement refresh failed: $e');
    }
    return isPro.value;
  }

  /// The offering to sell from (packages: monthly / yearly),
  /// or null when unavailable.
  Future<Offering?> currentOffering() async {
    if (!_configured) return null;
    try {
      return (await Purchases.getOfferings()).current;
    } catch (e) {
      debugPrint('RevenueCat offerings failed: $e');
      return null;
    }
  }

  /// Runs the purchase; returns true when Pro is active afterwards.
  /// Throws for real failures — but not when the user simply cancels.
  Future<bool> purchase(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    _onCustomerInfo(result.customerInfo);
    return isPro.value;
  }

  /// Re-syncs previous purchases (required by App Store rules).
  Future<bool> restore() async {
    final info = await Purchases.restorePurchases();
    _onCustomerInfo(info);
    return isPro.value;
  }

  /// RevenueCat's remote-configured paywall (dashboard → Paywalls).
  /// Shown only if the user doesn't already have the entitlement.
  Future<void> presentRemotePaywall() async {
    if (!_configured) return;
    await RevenueCatUI.presentPaywallIfNeeded(proEntitlementId);
  }

  /// RevenueCat Customer Center: manage/cancel subscription, refunds.
  Future<void> presentCustomerCenter() async {
    if (!_configured) return;
    await RevenueCatUI.presentCustomerCenter();
  }
}

/// The store refused because this store account already has the
/// subscription — Play's "You already own this item". It belongs to the
/// customer here, or to another account; a restore sorts out which.
bool isAlreadyOwnedError(Object error) =>
    error is PlatformException &&
    PurchasesErrorHelper.getErrorCode(error) ==
        PurchasesErrorCode.productAlreadyPurchasedError;

/// A user-facing message for a purchase failure, or null when the user
/// just cancelled and nothing should be shown.
String? purchaseErrorMessage(Object error) {
  if (error is PlatformException) {
    final code = PurchasesErrorHelper.getErrorCode(error);
    if (code == PurchasesErrorCode.purchaseCancelledError) return null;
    return switch (code) {
      PurchasesErrorCode.purchaseNotAllowedError =>
        'Purchases aren\'t allowed on this device.',
      PurchasesErrorCode.paymentPendingError =>
        'Your payment is pending — premium unlocks once it clears.',
      PurchasesErrorCode.networkError =>
        'Network trouble — check your connection and try again.',
      PurchasesErrorCode.productAlreadyPurchasedError =>
        'This store account already has a subscription. Sign in with the '
            'account you bought it with, or contact support.',
      _ => 'The purchase didn\'t go through. Please try again.',
    };
  }
  return 'The purchase didn\'t go through. Please try again.';
}
