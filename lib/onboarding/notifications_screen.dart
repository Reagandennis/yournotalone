import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
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

  static const _points = [
    (
      Icons.favorite_rounded,
      Brand.red,
      'Your therapy sessions',
      'When you\'re matched, if the time moves, and ten minutes before '
          'the call — so a paid session is never missed.',
    ),
    (
      Icons.notifications_active_rounded,
      Brand.blue,
      'Reminders you choose',
      'A morning check-in, evening pages, a wind-down. Each one is a '
          'switch in Settings; none is on until you say.',
    ),
    (
      Icons.block_rounded,
      Brand.ink,
      'Nothing else',
      'No marketing, no streak guilt, no "we miss you". If it isn\'t '
          'about your care, it isn\'t sent.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthSubmitButton(
            label: 'Turn on notifications',
            loading: _loading,
            onPressed: _loading ? null : _allow,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _loading ? null : _done,
            child: const Text('Maybe later'),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: Color(0x14FAB414),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_rounded,
              size: 42,
              color: Brand.yellow,
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Don\'t miss what matters',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 14),
        const Center(child: PillarStripe()),
        const SizedBox(height: 18),
        const Text(
          'Your phone will ask once. Here\'s exactly what a yes means.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.6),
        ),
        const SizedBox(height: 26),
        for (final (icon, colour, title, detail) in _points)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: colour),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Brand.textMuted,
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
