import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import '../l10n/l10n.dart';
import '../notifications/local_notifications.dart';
import '../therapy/session_format.dart';

/// The promise the paywall's timeline makes: a reminder before a free
/// trial turns into a charge.
///
/// Kept in step with RevenueCat's view of the entitlement rather than with
/// the purchase tap, so it also covers a trial started on another device
/// or restored here, and goes away if the trial is cancelled early.
abstract final class TrialReminder {
  static const _id = 300000001;

  static NotificationDetails _details(AppLocalizations l10n) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          'billing',
          l10n.billingTrialChannelName,
          channelDescription: l10n.billingTrialChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      );

  /// [pro] is the Pro entitlement as RevenueCat last reported it, or null
  /// when there is none.
  static Future<void> sync(EntitlementInfo? pro) async {
    if (LocalNotifications.silent) return;
    try {
      await LocalNotifications.ensureInitialized();
      final plugin = LocalNotifications.plugin;
      final expiry = pro?.expirationDate == null
          ? null
          : DateTime.tryParse(pro!.expirationDate!)?.toLocal();
      final trialRunning = pro != null &&
          pro.isActive &&
          pro.willRenew &&
          pro.periodType == PeriodType.trial &&
          expiry != null;
      if (!trialRunning) {
        await plugin.cancel(id: _id);
        return;
      }
      final at = _remindAt(expiry, DateTime.now());
      if (at == null) {
        await plugin.cancel(id: _id);
        return;
      }
      final l10n = currentL10n();
      final store = Platform.isIOS || Platform.isMacOS
          ? l10n.billingStoreAppStore
          : l10n.billingStoreGooglePlay;
      await plugin.zonedSchedule(
        id: _id,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _details(l10n),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: l10n.billingTrialReminderTitle,
        body: l10n.billingTrialReminderBody(formatDate(expiry), store),
      );
    } catch (e) {
      debugPrint('Trial reminder unavailable: $e');
    }
  }
}

/// When to remind: two days before the trial ends, mid-morning. A trial
/// too short for that gets a reminder two hours before it ends; one that
/// is already past its reminder point gets none.
@visibleForTesting
DateTime? remindAtFor(DateTime expiry, DateTime now) =>
    _remindAt(expiry, now);

DateTime? _remindAt(DateTime expiry, DateTime now) {
  final twoDaysBefore = expiry.subtract(const Duration(days: 2));
  final midMorning = DateTime(
    twoDaysBefore.year,
    twoDaysBefore.month,
    twoDaysBefore.day,
    10,
  );
  if (midMorning.isAfter(now)) return midMorning;
  final shortNotice = expiry.subtract(const Duration(hours: 2));
  if (shortNotice.isAfter(now)) return shortNotice;
  return null;
}
