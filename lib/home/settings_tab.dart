import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_redirect.dart';
import '../auth/auth_ui.dart';
import '../auth/login_screen.dart';
import '../billing/purchases_service.dart';
import '../brand.dart';
import '../legal/legal_content.dart';
import '../legal/legal_screen.dart';
import '../onboarding/paywall_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../reminders/reminders_screen.dart';
import '../support/faq_screen.dart';
import 'home_ui.dart';

/// Settings tab: profile, plan, account, support, legal, and log out.
class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Map<String, dynamic>? get _meta =>
      Supabase.instance.client.auth.currentUser?.userMetadata;

  Future<void> _openEditProfile(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    // Name or photo may have changed — re-read the auth metadata.
    if (mounted) setState(() {});
  }

  bool get _isPremium => isPremiumUser();

  Future<void> _manageSubscription(BuildContext context) async {
    if (!PurchasesService.instance.isConfigured) {
      showComingSoon(context, 'Subscription management');
      return;
    }
    await PurchasesService.instance.presentCustomerCenter();
  }

  Future<void> _restorePurchases(BuildContext context) async {
    if (!PurchasesService.instance.isConfigured) {
      showComingSoon(context, 'Restoring purchases');
      return;
    }
    try {
      final pro = await PurchasesService.instance.restore();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pro
                ? 'Premium restored — welcome back.'
                : 'No previous purchases found.'),
          ),
        );
      }
    } catch (e) {
      final message = purchaseErrorMessage(e);
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await Supabase.instance.client.auth
          .resetPasswordForEmail(email, redirectTo: authRedirectUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset link sent to $email')),
        );
      }
    } catch (e) {
      if (context.mounted) showAuthError(context, e);
    }
  }

  void _showCrisisResources(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Crisis resources'),
        content: const Text(
          'If you\'re in crisis or immediate danger, call your local '
          'emergency number right away.\n\nThis app can\'t replace emergency '
          'care — but a licensed therapist here is never far away, and your '
          'first session is free.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You can always come back — your progress stays safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Brand.red),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _profileCard(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final name = (_meta?['full_name'] as String?)?.trim();
    final displayName = (name == null || name.isEmpty) ? 'Your account' : name;
    final initial = displayName.characters.first.toUpperCase();
    final avatarUrl = (_meta?['avatar_url'] as String?) ?? '';
    final initialAvatar = Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Brand.blue,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Brand.border, width: 1.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Color(0x143764CD),
              shape: BoxShape.circle,
            ),
            child: avatarUrl.isEmpty
                ? initialAvatar
                : Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => initialAvatar,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user!.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Brand.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openEditProfile(context),
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: Brand.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context) {
    final premium = _isPremium;
    final checkin = (_meta?['wellbeing_checkin'] as String?) ?? 'steady';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x1FFAB414),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 22,
              color: Brand.yellow,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premium ? 'Premium' : 'Free plan',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  premium
                      ? 'Every room in the house is open.'
                      : '80% off your first month is waiting.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Brand.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (premium)
            TextButton(
              onPressed: () => _manageSubscription(context),
              child: const Text('Manage'),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaywallScreen(checkin: checkin),
                ),
              ),
              child: const Text('Upgrade'),
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color color = Brand.ink,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap ?? () => showComingSoon(context, label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 21, color: color == Brand.ink ? Brand.textMuted : color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14.5, color: color),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Brand.border,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Brand.textMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const PillarStripe(),
        const SizedBox(height: 24),
        _profileCard(context),
        const SizedBox(height: 14),
        _planCard(context),
        const SizedBox(height: 28),
        _sectionLabel('Account'),
        _row(
          context,
          Icons.person_outline_rounded,
          'Edit profile',
          onTap: () => _openEditProfile(context),
        ),
        _row(
          context,
          Icons.lock_outline_rounded,
          'Change password',
          onTap: () => _sendPasswordReset(context),
        ),
        _row(
          context,
          Icons.notifications_none_rounded,
          'Reminders & notifications',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RemindersScreen()),
          ),
        ),
        _row(
          context,
          Icons.restore_rounded,
          'Restore purchases',
          onTap: () => _restorePurchases(context),
        ),
        const SizedBox(height: 22),
        _sectionLabel('Support'),
        _row(
          context,
          Icons.health_and_safety_outlined,
          'Crisis resources',
          onTap: () => _showCrisisResources(context),
        ),
        _row(context, Icons.mail_outline_rounded, 'Contact us'),
        _row(
          context,
          Icons.help_outline_rounded,
          'FAQ',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const FaqScreen()),
          ),
        ),
        const SizedBox(height: 22),
        _sectionLabel('Legal'),
        _row(
          context,
          Icons.privacy_tip_outlined,
          'Privacy policy',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LegalScreen(doc: privacyPolicy)),
          ),
        ),
        _row(
          context,
          Icons.description_outlined,
          'Terms of service',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => LegalScreen(doc: termsOfService)),
          ),
        ),
        const SizedBox(height: 22),
        _sectionLabel('Account actions'),
        _row(
          context,
          Icons.logout_rounded,
          'Log out',
          color: Brand.red,
          onTap: () => _confirmLogout(context),
        ),
        _row(
          context,
          Icons.delete_outline_rounded,
          'Delete account',
          color: Brand.red,
        ),
        const SizedBox(height: 30),
        const Center(child: PillarStripe(width: 90, height: 4)),
        const SizedBox(height: 10),
        const Center(
          child: Text(
            'Δεν είσαι μόνος · v1.0.0',
            style: TextStyle(fontSize: 12, color: Brand.textMuted),
          ),
        ),
      ],
    );
  }
}
