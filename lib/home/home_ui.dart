import 'package:flutter/material.dart';
import '../billing/pricing_copy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../billing/purchases_service.dart';
import '../brand.dart';
import '../journal/journal_repository.dart';
import '../l10n/l10n.dart';
import '../onboarding/paywall_screen.dart';

/// First name of the signed-in user, from the signup metadata.
String firstNameOf() {
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
  final fullName = (meta?['full_name'] as String?)?.trim();
  if (fullName == null || fullName.isEmpty) {
    return currentL10n().homeUiFriendFallback;
  }
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
///
/// [item] is the thing they just tapped — a meditation, a sound, a prompt —
/// so the sheet is about *that* rather than about Premium in general.
/// [source] names the entry point for the paywall funnel metrics.
void showUpgradeSheet(
  BuildContext context, {
  required String title,
  required String message,
  String? item,
  String source = 'sheet',
}) {
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
  final checkin = (meta?['wellbeing_checkin'] as String?) ?? 'steady';
  Sentry.metrics.count('upgrade_sheet.shown', 1, attributes: {
    'source': SentryAttribute.string(source),
  });
  final c = context.brand;
  final l10n = context.l10n;
  showModalBottomSheet<void>(
    context: context,
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
            decoration: BoxDecoration(
              color: c.tint(Pillars.yellow, 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, size: 26, color: c.yellow),
          ),
          const SizedBox(height: 16),
          Text(
            item == null ? title : l10n.homeUiUnlockItem(item),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          if (item != null) ...[
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: c.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PaywallScreen(checkin: checkin, source: source),
                ),
              );
            },
            child: Text(
              item == null
                  ? l10n.homeUiSeePremium
                  : l10n.homeUiUnlockWithPremium,
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(l10n.commonNotNow),
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
    ? currentL10n().homeUiSignedOutError
    : ifOffline;

/// Whether a free user still has room for another journal entry, showing
/// the upgrade sheet when they don't.
///
/// Every route into the editor has to pass through here — the cap used to
/// live inside the journal list alone, so the hub's "Free write" and its
/// prompts handed out unlimited entries.
bool journalCapAllows(BuildContext context, int entryCount) {
  if (isPremiumUser() || entryCount < freeJournalEntryLimit) return true;
  final l10n = context.l10n;
  showUpgradeSheet(
    context,
    title: l10n.homeUiJournalCapTitle,
    message: l10n.homeUiJournalCapMessage(freeJournalEntryLimit, introOffer),
  );
  return false;
}

/// Standard placeholder for features that aren't built yet.
void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(context.l10n.homeUiComingSoon(feature))),
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
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.brand.ink,
            ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              context.l10n.homeUiSeeAll,
              style: const TextStyle(fontSize: 13),
            ),
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
    final c = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.tint(Pillars.yellow, 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 10, color: c.ink),
          const SizedBox(width: 3),
          Text(
            context.l10n.homeUiPremiumChip,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
        ],
      ),
    );
  }
}
