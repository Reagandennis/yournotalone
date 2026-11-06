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
import '../backgrounds/background_strings.dart';
import '../backgrounds/calm_visuals.dart';
import '../auth/login_screen.dart';
import '../billing/purchases_service.dart';
import '../brand.dart';
import '../brand_layout.dart';
import '../care/care_dashboard_screen.dart';
import '../care/care_repository.dart';
import '../care/therapist_sessions_screen.dart';
import '../content/content_catalog.dart';
import '../discover/content_widgets.dart';
import '../discover/goals.dart';
import '../l10n/l10n.dart';
import '../l10n/language_picker.dart';
import '../legal/legal_content.dart';
import '../notifications/session_notifications.dart';
import '../legal/legal_screen.dart';
import '../media/download_strings.dart';
import '../media/downloads_screen.dart';
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditProfileScreen()));
    // Name or photo may have changed — re-read the auth metadata.
    if (mounted) setState(() {});
  }

  bool get _isPremium => isPremiumUser();

  final _careRoles = CareRepository().fetchRoles();

  Future<void> _manageSubscription(BuildContext context) async {
    if (!PurchasesService.instance.isConfigured) {
      showComingSoon(context, context.l10n.settingsSubscriptionManagement);
      return;
    }
    await PurchasesService.instance.presentCustomerCenter();
  }

  Future<void> _restorePurchases(BuildContext context) async {
    if (!PurchasesService.instance.isConfigured) {
      showComingSoon(context, context.l10n.settingsRestoringPurchases);
      return;
    }
    try {
      final pro = await PurchasesService.instance.restore();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pro
                  ? context.l10n.settingsPremiumRestored
                  : context.l10n.settingsNoPurchasesFound,
            ),
          ),
        );
      }
    } catch (e) {
      final message = purchaseErrorMessage(e);
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: authRedirectUrl,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsPasswordResetSent(email))),
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
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
      throw Exception('no mail app');
    } catch (_) {
      if (!context.mounted) return;
      // No mail app configured — hand over the address instead of failing.
      await Clipboard.setData(const ClipboardData(text: legalContactEmail));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.settingsEmailCopied(legalContactEmail)),
        ),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settingsLogOutTitle),
        content: Text(context.l10n.settingsLogOutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.brand.red),
            child: Text(context.l10n.settingsLogOut),
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
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(context.l10n.settingsDeleting)),
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
        SnackBar(content: Text(context.l10n.settingsDeleteFailed)),
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
    final displayName = (name == null || name.isEmpty) ? context.l10n.settingsYourAccount : name;
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
                    style: TextStyle(fontSize: 12.5, color: c.textMuted),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _openEditProfile(context),
            icon: Icon(Icons.edit_outlined, size: 20, color: c.textMuted),
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
            decoration: BoxDecoration(color: c.chip, shape: BoxShape.circle),
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
                  premium ? context.l10n.settingsPremiumPlan : context.l10n.settingsFreePlan,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  premium
                      ? context.l10n.settingsPremiumTagline
                      : introOfferSentence,
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
              ],
            ),
          ),
          if (premium)
            TextButton(
              onPressed: () => _manageSubscription(context),
              child: Text(context.l10n.settingsManage),
            )
          else
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      PaywallScreen(checkin: checkin, source: 'settings'),
                ),
              ),
              child: Text(context.l10n.settingsUpgrade),
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
            _sectionLabel(context.l10n.settingsCareTeam),
            if (roles.isAdmin)
              _row(
                context,
                Icons.space_dashboard_outlined,
                context.l10n.settingsCareDashboard,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CareDashboardScreen(),
                  ),
                ),
              ),
            if (roles.isTherapist)
              _row(
                context,
                Icons.video_call_outlined,
                context.l10n.settingsMyTherapySessions,
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
              // Shortened rather than pushed off the edge, on a small
              // phone with large text.
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 13, color: c.textMuted),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: c.border),
          ],
        ),
      ),
    );
  }

  /// Calm visuals on or off: a switch, since there's nothing to choose
  /// between. Off holds the backgrounds behind sounds and sessions still.
  Widget _calmVisualsRow(BuildContext context) {
    final c = context.brand;
    final setting = CalmVisualsSetting.instance;
    return ListenableBuilder(
      listenable: setting,
      builder: (context, _) => MergeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setting.setEnabled(!setting.enabled),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.blur_on_rounded, size: 21, color: c.textMuted),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    BackgroundStrings.calmVisuals,
                    style: TextStyle(fontSize: 14.5, color: c.ink),
                  ),
                ),
                Switch.adaptive(
                  value: setting.enabled,
                  onChanged: setting.setEnabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Sleep, Anxious", or "+3" past two, for the settings row.
  String? _goalsSummary() {
    final goals = userGoals();
    if (goals.isEmpty) return null;
    final names = [for (final g in goals) g.label(context.l10n)];
    return names.length <= 2
        ? names.join(', ')
        : context.l10n.settingsGoalsMore(
            names.take(2).join(', '),
            names.length - 2,
          );
  }

  /// The reasons asked at onboarding, editable: they put matching
  /// suggestions, needs and courses first.
  Future<void> _chooseGoals(BuildContext context) async {
    final picked = {...userGoals()};
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final c = sheetContext.brand;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sheetContext.l10n.settingsGoalsTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sheetContext.l10n.settingsGoalsSub,
                    style: TextStyle(fontSize: 13, color: c.textMuted),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final need in goalChoices)
                        FilterPill(
                          label: need.label(sheetContext.l10n),
                          icon: need.icon,
                          color: need.color,
                          selected: picked.contains(need),
                          onTap: () => setSheet(() {
                            if (!picked.remove(need)) picked.add(need);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await saveGoals(picked);
                      if (mounted) setState(() {});
                    },
                    child: Text(sheetContext.l10n.commonSave),
                  ),
                ],
              ),
            ),
          );
        },
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
                      sheetContext.l10n.settingsAppearance,
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
                        appearanceLabel(sheetContext.l10n, mode),
                        style: TextStyle(fontSize: 14.5, color: c.ink),
                      ),
                      subtitle: mode == ThemeMode.system
                          ? Text(
                              sheetContext.l10n.settingsAppearanceSystemHint,
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
  Widget build(BuildContext context) =>
      PremiumBuilder(builder: (context, _) => _buildContent(context));

  /// Wrapped by [PremiumBuilder] above, so this repaints the moment the
  /// entitlement changes — buying from inside the app used to leave the
  /// screen you bought from still locked.
  Widget _buildContent(BuildContext context) {
    final c = context.brand;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      children: [
        Text(
          context.l10n.settingsTitle,
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
        // Side by side where there's room: you and your settings on the
        // left, help and the small print on the right.
        TwoColumns(
          first: [
            _profileCard(context),
            const SizedBox(height: 14),
            _planCard(context),
            _careSection(context),
            const SizedBox(height: 28),
            _sectionLabel(context.l10n.settingsAccount),
            _row(
              context,
              Icons.person_outline_rounded,
              context.l10n.settingsEditProfile,
              onTap: () => _openEditProfile(context),
            ),
            _row(
              context,
              Icons.lock_outline_rounded,
              context.l10n.settingsChangePassword,
              onTap: () => _sendPasswordReset(context),
            ),
            _row(
              context,
              Icons.notifications_none_rounded,
              context.l10n.settingsReminders,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RemindersScreen())),
            ),
            _row(
              context,
              Icons.flag_outlined,
              context.l10n.settingsGoals,
              value: _goalsSummary(),
              onTap: () => _chooseGoals(context),
            ),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: AppearanceSetting.instance,
              builder: (context, mode, _) => _row(
                context,
                Icons.contrast_rounded,
                context.l10n.settingsAppearance,
                value: appearanceLabel(context.l10n, mode),
                onTap: () => _chooseAppearance(context),
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: LocaleSetting.instance,
              builder: (context, tag, _) => _row(
                context,
                Icons.translate_rounded,
                context.l10n.languageTitle,
                value: languageSummary(context, tag),
                onTap: () => showLanguagePicker(context),
              ),
            ),
            _calmVisualsRow(context),
            // Only with the catalogue snapshot on: before that, all audio ships
            // inside the app and there's nothing to download.
            if (catalogSnapshotEnabled)
              _row(
                context,
                Icons.download_for_offline_outlined,
                DownloadStrings.settingsRow,
                onTap: () => Navigator.of(context).push(DownloadsScreen.route()),
              ),
            _row(
              context,
              Icons.restore_rounded,
              context.l10n.settingsRestorePurchases,
              onTap: () => _restorePurchases(context),
            ),
          ],
          second: [
            const SizedBox(height: 22),
            _sectionLabel(context.l10n.settingsSupport),
            _row(
              context,
              Icons.health_and_safety_outlined,
              context.l10n.settingsCrisisResources,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CrisisScreen())),
            ),
            _row(
              context,
              Icons.mail_outline_rounded,
              context.l10n.settingsContactUs,
              onTap: () => _contactSupport(context),
            ),
            _row(
              context,
              Icons.help_outline_rounded,
              context.l10n.settingsFaq,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FaqScreen())),
            ),
            const SizedBox(height: 22),
            _sectionLabel(context.l10n.settingsLegal),
            _row(
              context,
              Icons.privacy_tip_outlined,
              context.l10n.settingsPrivacyPolicy,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LegalScreen(doc: privacyPolicy)),
              ),
            ),
            _row(
              context,
              Icons.description_outlined,
              context.l10n.settingsTerms,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => LegalScreen(doc: termsOfService)),
              ),
            ),
            const SizedBox(height: 22),
            _sectionLabel(context.l10n.settingsAccountActions),
            _row(
              context,
              Icons.logout_rounded,
              context.l10n.settingsLogOut,
              color: c.red,
              onTap: () => _confirmLogout(context),
            ),
            _row(
              context,
              Icons.delete_outline_rounded,
              context.l10n.settingsDeleteAccount,
              color: c.red,
              onTap: () => _confirmDelete(context),
            ),
          ],
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
      title: Text(context.l10n.settingsDeleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.settingsDeleteBody),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.l10n.settingsTypeToConfirm('DELETE'),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.settingsKeepAccount),
        ),
        TextButton(
          onPressed: armed ? () => Navigator.of(context).pop(true) : null,
          style: TextButton.styleFrom(foregroundColor: context.brand.red),
          child: Text(context.l10n.settingsDeleteForGood),
        ),
      ],
    );
  }
}
