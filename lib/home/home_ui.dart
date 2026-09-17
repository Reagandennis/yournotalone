import 'package:flutter/material.dart';
import '../billing/pricing_copy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../billing/purchases_service.dart';
import '../brand.dart';
import '../journal/journal_repository.dart';
import '../onboarding/paywall_screen.dart';

/// First name of the signed-in user, from the signup metadata.
String firstNameOf() {
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
  final fullName = (meta?['full_name'] as String?)?.trim();
  if (fullName == null || fullName.isEmpty) return 'friend';
  return fullName.split(RegExp(r'\s+')).first;
}

/// App-metadata flag that grants premium regardless of billing — for your
/// own account, testers, the Play reviewer, and support goodwill. Set it by
/// hand in SQL; nothing in the app ever writes it. See
/// supabase/account_ops.sql.
///
/// It lives in `app_metadata`, which only the service role can write. It
/// used to be in `user_metadata`, which any signed-in user can set through
/// the public auth API — so anyone could grant themselves premium.
const compPremiumKey = 'premium_comp';

/// Whether the user has premium.
///
/// Two sources, in order:
///
/// 1. A live RevenueCat entitlement — a real, current subscription.
/// 2. A comp grant we set by hand ([compPremiumKey]).
///
/// `plan_choice` is deliberately not one: the app writes it at the paywall,
/// so it says what someone picked, not what they paid for, and being in
/// user metadata anyone can set it. It used to stand in when RevenueCat
/// couldn't answer, which on such a platform was a self-grant.
///
/// [user] is only for tests; the app always checks the signed-in user.
bool isPremiumUser([User? user]) {
  if (PurchasesService.instance.isPro.value) return true;
  final account = user ?? Supabase.instance.client.auth.currentUser;
  return account?.appMetadata[compPremiumKey] == true;
}

/// Rebuilds [builder] whenever the entitlement changes.
///
/// Without this, buying Premium from inside a screen left that screen
/// locked until it happened to rebuild: `isPro` is a ValueNotifier and
/// nothing was listening to it.
class PremiumBuilder extends StatelessWidget {
  const PremiumBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, bool premium) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PurchasesService.instance.isPro,
      builder: (context, _, _) => builder(context, isPremiumUser()),
    );
  }
}

/// Bottom sheet nudging free users toward Premium, leading to the paywall.
void showUpgradeSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
  final checkin = (meta?['wellbeing_checkin'] as String?) ?? 'steady';
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0x1FFAB414),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, size: 26, color: Brand.yellow),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              color: Brand.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaywallScreen(checkin: checkin),
                ),
              );
            },
            child: const Text('See Premium'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Not now'),
          ),
        ],
      ),
    ),
  );
}

/// What to tell the user about a caught error.
///
/// Most failures here really are the network, but a lost session throws
/// `StateError('Not signed in')` from the repositories — and telling
/// someone to check their connection when the fix is to log in again sends
/// them somewhere they can't get out of.
String errorMessage(Object error, String ifOffline) => error is StateError
    ? 'You\'ve been signed out. Please log in again.'
    : ifOffline;

/// Whether a free user still has room for another journal entry, showing
/// the upgrade sheet when they don't.
///
/// Every route into the editor has to pass through here — the cap used to
/// live inside the journal list alone, so the hub's "Free write" and its
/// prompts handed out unlimited entries.
bool journalCapAllows(BuildContext context, int entryCount) {
  if (isPremiumUser() || entryCount < freeJournalEntryLimit) return true;
  showUpgradeSheet(
    context,
    title: 'You\'ve filled your free pages',
    message: 'The free plan includes $freeJournalEntryLimit journal entries. '
        'Premium unlocks unlimited journaling — and $introOffer.',
  );
  return false;
}

/// Standard placeholder for features that aren't built yet.
void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('$feature is coming soon — stay close.')),
    );
}

/// Section heading used across the tabs, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text('See all', style: TextStyle(fontSize: 13)),
          ),
      ],
    );
  }
}

/// Small "Premium" chip shown on locked content.
class PremiumChip extends StatelessWidget {
  const PremiumChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x1FFAB414),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 10, color: Brand.ink),
          SizedBox(width: 3),
          Text(
            'Premium',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
        ],
      ),
    );
  }
}
