import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../l10n/l10n.dart';
import '../home/home_shell.dart';
import '../notifications/notification_permission.dart';
import 'onboarding_ui.dart';

/// The last onboarding step: ask for notifications while the person still
/// has the context to say yes. It explains the three things we'll ever
/// notify about, asks, and moves on either way — a refusal here is picked
/// up again at the moments that matter.
class NotificationsSetupScreen extends StatefulWidget {
  const NotificationsSetupScreen({super.key, this.permission, this.onDone});

  final NotificationPermission? permission;

  /// What happens after the choice; Home when not given.
  final VoidCallback? onDone;

  @override
  State<NotificationsSetupScreen> createState() =>
      _NotificationsSetupScreenState();
}

class _NotificationsSetupScreenState extends State<NotificationsSetupScreen> {
  late final _permission = widget.permission ?? NotificationPermission.instance;
  bool _loading = false;

  void _done() {
    if (widget.onDone != null) {
      widget.onDone!();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (route) => false,
    );
  }

  Future<void> _allow() async {
    setState(() => _loading = true);
    await _permission.request();
    if (!mounted) return;
    setState(() => _loading = false);
    _done();
  }

  static List<(IconData, Color, String, String)> _points(
    AppLocalizations l10n,
  ) => [
    (
      Icons.favorite_rounded,
      Pillars.red,
      l10n.onboardingNotificationsSessionsTitle,
      l10n.onboardingNotificationsSessionsDetail,
    ),
    (
      Icons.notifications_active_rounded,
      Pillars.blue,
      l10n.onboardingNotificationsRemindersTitle,
      l10n.onboardingNotificationsRemindersDetail,
    ),
    (
      Icons.block_rounded,
      Pillars.black,
      l10n.onboardingNotificationsNothingElseTitle,
      l10n.onboardingNotificationsNothingElseDetail,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    return OnboardingScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthSubmitButton(
            label: l10n.onboardingNotificationsTurnOn,
            loading: _loading,
            onPressed: _loading ? null : _allow,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _loading ? null : _done,
            child: Text(l10n.onboardingNotificationsMaybeLater),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: c.tint(Pillars.yellow, 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_rounded,
              size: 42,
              color: c.yellow,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          l10n.onboardingNotificationsTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: c.ink,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        const Center(child: PillarStripe()),
        const SizedBox(height: 18),
        Text(
          l10n.onboardingNotificationsIntro,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.6),
        ),
        const SizedBox(height: 26),
        for (final (icon, colour, title, detail) in _points(l10n))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.tint(colour, 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: c.accent(colour)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
