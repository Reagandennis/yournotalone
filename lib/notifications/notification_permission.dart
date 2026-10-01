import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../reminders/reminders_service.dart';
import 'local_notifications.dart';

/// Where the app stands with the phone's notification permission.
enum NotificationAccess {
  /// The OS will show our notifications.
  enabled,

  /// We've never asked (or the OS has never been asked for this install),
  /// so a request will show the system prompt.
  notAsked,

  /// Asked and refused, or switched off in Settings. Only the person can
  /// change that, in the phone's settings.
  denied,
}

/// Why we're asking, in the person's terms. Shown in the prompts so the
/// request never arrives out of the blue.
abstract final class NotificationReasons {
  static const session =
      'We\'ll tell you the moment you\'re matched with a therapist, if your '
      'session moves, and ten minutes before it starts — so you don\'t miss '
      'a session you\'ve paid for.';
  static const therapist =
      'You\'ll be told when a session is booked with you, if it changes, and '
      'ten minutes before it starts.';
  static const reminders =
      'Reminders are notifications: without permission the phone can\'t '
      'show them.';
  static const onboarding =
      'Session bookings, a nudge before each session starts, and the daily '
      'reminders you choose. Nothing else.';
}

/// Everything about notification permission in one place: what the OS
/// says, asking for it at the right moments, and — when it's been refused —
/// pointing people at the one place they can turn it back on.
///
/// Android 13+ and iOS both need an explicit yes. People tap "Don't allow"
/// in a hurry during onboarding and then miss a therapist match, so the app
/// asks once up front, asks again at the moments that matter, and keeps a
/// visible banner wherever a missed notification would cost them.
class NotificationPermission {
  NotificationPermission({
    this._isEnabled,
    this._request,
    this._openSettings,
  });

  static NotificationPermission instance = NotificationPermission();

  static const _askedKey = 'notifications.asked';
  static const _channel = MethodChannel('yournotalone/notifications');

  /// Widget tests have no OS to ask; they get "enabled" unless a test
  /// injects its own answers.
  static final bool _silent = Platform.environment.containsKey('FLUTTER_TEST');

  final Future<bool> Function()? _isEnabled;
  final Future<bool> Function()? _request;
  final Future<void> Function()? _openSettings;

  FlutterLocalNotificationsPlugin get _plugin => LocalNotifications.plugin;

  /// What the OS will actually do with a notification right now.
  Future<bool> isEnabled() async {
    if (_isEnabled != null) return _isEnabled();
    if (_silent) return true;
    try {
      await LocalNotifications.ensureInitialized();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? true;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final options = await ios.checkPermissions();
        // Provisional (quiet) delivery counts: the notification still lands.
        return options == null ||
            options.isEnabled ||
            options.isProvisionalEnabled;
      }
      final macos = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        final options = await macos.checkPermissions();
        return options == null || options.isEnabled;
      }
    } catch (e) {
      debugPrint('Notification permission check failed: $e');
    }
    return true;
  }

  Future<bool> _wasAsked() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_askedKey) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markAsked() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_askedKey, true);
    } catch (_) {
      // Worst case we ask once more; the OS won't prompt twice anyway.
    }
  }

  Future<NotificationAccess> status() async {
    if (await isEnabled()) return NotificationAccess.enabled;
    return await _wasAsked()
        ? NotificationAccess.denied
        : NotificationAccess.notAsked;
  }

  /// Shows the system prompt (once per install — after that the OS answers
  /// from memory). True when notifications are enabled afterwards.
  Future<bool> request() async {
    await _markAsked();
    if (_request != null) return _request();
    if (_silent) return true;
    final granted = await RemindersService.instance.requestPermission();
    // Android reports the dialog's answer; a re-check catches the case where
    // the dialog never appeared because the channel is switched off.
    return granted && await isEnabled();
  }

  /// For app start: people who signed up before the app asked, or who
  /// skipped the onboarding step, get the system prompt exactly once.
  Future<void> promptIfNeverAsked() async {
    if (await status() == NotificationAccess.notAsked) await request();
  }

  /// Makes sure notifications can arrive before something that depends on
  /// them: asks if we never have, or explains where to turn them on if they
  /// were refused. True when they're enabled by the end.
  Future<bool> ensure(BuildContext context, {required String reason}) async {
    switch (await status()) {
      case NotificationAccess.enabled:
        return true;
      case NotificationAccess.notAsked:
        if (await request()) return true;
        if (!context.mounted) return false;
        return showSettingsDialog(context, reason: reason);
      case NotificationAccess.denied:
        if (!context.mounted) return false;
        return showSettingsDialog(context, reason: reason);
    }
  }

  /// Opens this app's notification settings on the phone.
  Future<void> openSettings() async {
    if (_openSettings != null) return _openSettings();
    if (_silent) return;
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>('openSettings');
      } else {
        await launchUrl(Uri.parse('app-settings:'));
      }
    } catch (e) {
      debugPrint('Couldn\'t open notification settings: $e');
    }
  }

  /// The "they said no" path: a short, honest dialog with the one useful
  /// button. Returns true if notifications are enabled when it closes.
  Future<bool> showSettingsDialog(
    BuildContext context, {
    required String reason,
  }) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications are off'),
        content: Text(
          '$reason\n\nThey\'re switched off for this app at the moment. '
          'You can turn them on in your phone\'s settings — it takes a '
          'few seconds.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (open == true) await openSettings();
    return isEnabled();
  }
}

/// A banner for the places where a missed notification would matter — the
/// therapy screen while a session is on the way, above all. Shown only
/// while notifications are off; tapping it takes the shortest route back.
class NotificationsOffBanner extends StatelessWidget {
  const NotificationsOffBanner({
    super.key,
    required this.message,
    required this.reason,
    required this.onChanged,
    this.permission,
  });

  final String message;
  final String reason;

  /// Called with the new state after the person acts on the banner.
  final ValueChanged<bool> onChanged;
  final NotificationPermission? permission;

  @override
  Widget build(BuildContext context) {
    final permission = this.permission ?? NotificationPermission.instance;
    return Material(
      color: const Color(0x24FAB414),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 20,
              color: Brand.ink,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Brand.ink,
                  height: 1.4,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final on = await permission.ensure(context, reason: reason);
                onChanged(on);
              },
              child: const Text('Turn on'),
            ),
          ],
        ),
      ),
    );
  }
}
