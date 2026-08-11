import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../billing/purchases_service.dart';
import '../brand.dart';
import '../onboarding/paywall_screen.dart';

/// First name of the signed-in user, from the signup metadata.
String firstNameOf() {
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
  final fullName = (meta?['full_name'] as String?)?.trim();
  if (fullName == null || fullName.isEmpty) return 'friend';
  return fullName.split(RegExp(r'\s+')).first;
}

/// Whether the user has premium. The RevenueCat entitlement is the
/// source of truth; the metadata flag covers pre-billing test accounts.
bool isPremiumUser() {
  if (PurchasesService.instance.isPro.value) return true;
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
  return (meta?['plan_choice'] as String?)?.startsWith('premium') ?? false;
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
