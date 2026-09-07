import 'package:flutter/material.dart';
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

/// Whether the user has premium.
///
/// RevenueCat is the source of truth whenever it is configured — the
/// `plan_choice` metadata flag is written once at purchase and never
/// cleared, so trusting it there would keep premium alive through a
/// cancellation, a refund and an expiry. It stays as the fallback for
/// pre-billing test accounts and platforms where the SDK isn't set up.
bool isPremiumUser() {
  final purchases = PurchasesService.instance;
  if (purchases.isConfigured) return purchases.isPro.value;
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
  return (meta?['plan_choice'] as String?)?.startsWith('premium') ?? false;
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
        'Premium unlocks unlimited journaling — and your first month is '
        '80% off.',
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
