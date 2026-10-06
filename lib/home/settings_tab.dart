import 'package:flutter/material.dart';
import '../billing/pricing_copy.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../account/account_repository.dart';
import '../appearance.dart';
import '../auth/auth_redirect.dart';
import '../auth/auth_ui.dart';
import '../auth/google_auth.dart';
import '../auth/login_screen.dart';
import '../billing/purchases_service.dart';
import '../brand.dart';
import '../care/care_dashboard_screen.dart';
import '../care/care_repository.dart';
import '../care/therapist_sessions_screen.dart';
import '../legal/legal_content.dart';
import '../notifications/session_notifications.dart';
import '../legal/legal_screen.dart';
import '../onboarding/paywall_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../reminders/reminders_screen.dart';
import '../support/crisis_screen.dart';
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

  final _careRoles = CareRepository().fetchRoles();

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

  Future<void> _contactSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: legalContactEmail,
      queryParameters: {'subject': 'yournotalone — support'},
    );
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched || !context.mounted) return;
      throw Exception('no mail app');
    } catch (_) {
      if (!context.mounted) return;
      // No mail app configured — hand over the address instead of failing.
      await Clipboard.setData(const ClipboardData(text: legalContactEmail));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email address copied: $legalContactEmail'),
        ),
      );
    }
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
            style: TextButton.styleFrom(foregroundColor: context.brand.red),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // While still signed in, so the server forgets this phone too.
    await SessionNotifications.instance.stop();
    // Drop the remembered Google account too, so the next sign-in offers the
    // picker instead of jumping straight back into the account just left.
    await GoogleAuth.signOut();
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Deleting the account: name what goes, make the user type DELETE, then
  /// carry it out and drop them back at the login screen. The privacy
  /// policy, the terms and the FAQ all promise this works — so it has to
  /// either finish or say plainly that it didn't.
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Deleting your account…')),
          ],
        ),
      ),
    );

    try {
      await AccountRepository().deleteAccount();
    } on Object catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // the progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn\'t finish deleting your account. Your request is on '
            'file and we\'ll complete it — or try again.',
          ),
        ),
      );
      return;
    }

    // The account is gone. Signing out now talks to a user that no longer
    // exists, so a failure here is expected and must not be reported as a
    // failed deletion.
    try {
      await GoogleAuth.signOut();
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Nothing to do — the session is dead either way.
    }

    if (!context.mounted) return;
    Navigator.of(context).pop(); // the progress dialog
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _profileCard(BuildContext context) {
    final c = context.brand;
    final user = Supabase.instance.client.auth.currentUser;
    final name = (_meta?['full_name'] as String?)?.trim();
    final displayName = (name == null || name.isEmpty) ? 'Your account' : name;
    final initial = displayName.characters.first.toUpperCase();
    final avatarUrl = (_meta?['avatar_url'] as String?) ?? '';
    final initialAvatar = Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: c.blue,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border, width: 1.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.tint(Pillars.blue, 0.08),
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
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user!.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openEditProfile(context),
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: c.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context) {
    final c = context.brand;
    final premium = _isPremium;
    final checkin = (_meta?['wellbeing_checkin'] as String?) ?? 'steady';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.tint(Pillars.yellow, 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.chip,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              size: 22,
              color: c.yellow,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  premium ? 'Premium' : 'Free plan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  premium
                      ? 'Every room in the house is open.'
                      : introOfferSentence,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textMuted,
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
                  builder: (_) =>
                      PaywallScreen(checkin: checkin, source: 'settings'),
                ),
              ),
              child: const Text('Upgrade'),
            ),
        ],
      ),
    );
  }

  /// For the care team and therapists only. Roles come from the server, so
  /// for everyone else this section never appears.
  Widget _careSection(BuildContext context) {
    return FutureBuilder<CareRoles>(
      future: _careRoles,
      builder: (context, snapshot) {
        final roles = snapshot.data ?? CareRoles.none;
        if (!roles.isAdmin && !roles.isTherapist) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 28),
            _sectionLabel('Care team'),
            if (roles.isAdmin)
              _row(
                context,
                Icons.space_dashboard_outlined,
                'Care team dashboard',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CareDashboardScreen()),
                ),
              ),
            if (roles.isTherapist)
              _row(
                context,
                Icons.video_call_outlined,
                'My therapy sessions',
                onTap: () =>
                    Navigator.of(context).push(TherapistSessionsScreen.route()),
              ),
          ],
        );
      },
    );
  }

  /// A settings row. [color] tints a warning row (log out, delete);
  /// [value] shows the current choice, as for Appearance.
  Widget _row(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
    Color? color,
    String? value,
  }) {
    final c = context.brand;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap ?? () => showComingSoon(context, label),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 21, color: color ?? c.textMuted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14.5, color: color ?? c.ink),
              ),
            ),
            if (value != null) ...[
              Text(value, style: TextStyle(fontSize: 13, color: c.textMuted)),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: c.border,
            ),
          ],
        ),
      ),
    );
  }

  /// Match my phone, Light or Dark. The app changes as soon as one is
  /// picked, so the sheet stays open long enough to see it.
  Future<void> _chooseAppearance(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppearanceSetting.instance,
        builder: (sheetContext, current, _) {
          final c = sheetContext.brand;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                  ),
                  for (final (mode, icon) in const [
                    (ThemeMode.system, Icons.brightness_auto_outlined),
                    (ThemeMode.light, Icons.light_mode_outlined),
                    (ThemeMode.dark, Icons.dark_mode_outlined),
                  ])
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(icon, color: c.textMuted),
                      title: Text(
                        appearanceLabel(mode),
                        style: TextStyle(fontSize: 14.5, color: c.ink),
                      ),
                      subtitle: mode == ThemeMode.system
                          ? Text(
                              'Light by day, dark when your phone is.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textMuted,
                              ),
                            )
                          : null,
                      trailing: mode == current
                          ? Icon(Icons.check_rounded, color: c.blue)
                          : null,
                      selected: mode == current,
                      onTap: () => AppearanceSetting.instance.choose(mode),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.brand.textMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PremiumBuilder(
        builder: (context, _) => _buildContent(context),
      );

  /// Wrapped by [PremiumBuilder] above, so this repaints the moment the
  /// entitlement changes — buying from inside the app used to leave the
  /// screen you bought from still locked.
  Widget _buildContent(BuildContext context) {
    final c = context.brand;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        Text(
          'Settings',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: c.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const PillarStripe(),
        const SizedBox(height: 24),
        _profileCard(context),
        const SizedBox(height: 14),
        _planCard(context),
        _careSection(context),
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
        ValueListenableBuilder<ThemeMode>(
          valueListenable: AppearanceSetting.instance,
          builder: (context, mode, _) => _row(
            context,
            Icons.contrast_rounded,
            'Appearance',
            value: appearanceLabel(mode),
            onTap: () => _chooseAppearance(context),
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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CrisisScreen()),
          ),
        ),
        _row(
          context,
          Icons.mail_outline_rounded,
          'Contact us',
          onTap: () => _contactSupport(context),
        ),
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
          color: c.red,
          onTap: () => _confirmLogout(context),
        ),
        _row(
          context,
          Icons.delete_outline_rounded,
          'Delete account',
          color: c.red,
          onTap: () => _confirmDelete(context),
        ),
        const SizedBox(height: 30),
        const Center(child: PillarStripe(width: 90, height: 4)),
        const SizedBox(height: 10),
        Center(
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final info = snapshot.data;
              final version = info == null
                  ? ''
                  : ' · v${info.version} (${info.buildNumber})';
              return Text(
                'yournotalone$version',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Confirmation for deleting an account. It's a widget rather than an
/// inline builder so the text controller is disposed with the route — a
/// controller disposed while the dismiss animation is still running throws.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final armed = _controller.text.trim().toUpperCase() == 'DELETE';
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This removes your profile, journal entries, mood check-ins, '
            'recovery streaks, craving logs, therapy requests and photo. '
            'It happens straight away and it can\'t be undone.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep my account'),
        ),
        TextButton(
          onPressed: armed ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: context.brand.red),
          child: const Text('Delete for good'),
        ),
      ],
    );
  }
}
