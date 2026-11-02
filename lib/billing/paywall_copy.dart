import 'package:purchases_flutter/purchases_flutter.dart';

import '../l10n/l10n.dart';

/// What the paywall says to *this* person.
///
/// The onboarding check-in ("steady", "stressed", "struggling",
/// "dark_place") used to be saved at the paywall and never read. It is the
/// one thing the app knows about someone before asking them to pay, so
/// the headline speaks to it instead of to "Premium" in the abstract.
({String headline, String detail}) paywallCopy(
  String checkin, [
  AppLocalizations? l10n,
]) {
  l10n ??= currentL10n();
  return switch (checkin) {
    'struggling' || 'dark_place' => (
        headline: l10n.paywallHardWeeksHeadline,
        detail: l10n.paywallHardWeeksDetail,
      ),
    'stressed' => (
        headline: l10n.paywallStressedHeadline,
        detail: l10n.paywallStressedDetail,
      ),
    _ => (
        headline: l10n.paywallSteadyHeadline,
        detail: l10n.paywallSteadyDetail,
      ),
  };
}

/// Which plan to start with selected.
///
/// A year up front is the better deal, and the natural choice for someone
/// building habits. On a hard week it's also a big ask; monthly is the
/// gentler door, and the trial is the same either way.
PackageType preferredPlan(String checkin) => switch (checkin) {
      'struggling' || 'dark_place' => PackageType.monthly,
      _ => PackageType.annual,
    };

/// Days in a package's free trial, or null when it has none.
int? trialDays(Package package) {
  final intro = package.storeProduct.introductoryPrice;
  if (intro == null || intro.price > 0) return null;
  final unit = switch (intro.periodUnit) {
    PeriodUnit.day => 1,
    PeriodUnit.week => 7,
    PeriodUnit.month => 30,
    PeriodUnit.year => 365,
    _ => 1,
  };
  return intro.periodNumberOfUnits * unit;
}

/// "3 days" / "1 week" / "1 month" for a package's free trial.
String? trialLabel(Package package, [AppLocalizations? l10n]) {
  l10n ??= currentL10n();
  final intro = package.storeProduct.introductoryPrice;
  if (intro == null || intro.price > 0) return null;
  final n = intro.periodNumberOfUnits;
  return switch (intro.periodUnit) {
    PeriodUnit.week => l10n.billingTrialWeeks(n),
    PeriodUnit.month => l10n.billingTrialMonths(n),
    PeriodUnit.year => l10n.billingTrialYears(n),
    _ => l10n.billingTrialDays(n),
  };
}

/// A yearly price as "Ksh 750/month", in the store's own currency and
/// symbol placement. The symbol is whatever is left of the store's price
/// string once digits and separators go, so "Ksh 9,000.00" gives "Ksh",
/// "$79.99" gives "$", and the app never hard-codes a currency.
String perMonthLabel(Package yearly, [AppLocalizations? l10n]) {
  l10n ??= currentL10n();
  final perMonth = l10n.billingSuffixMonth;
  final priceString = yearly.storeProduct.priceString;
  final amount = yearly.storeProduct.price / 12;
  final symbol = priceString.replaceAll(RegExp(r'[\d.,\s]'), '');
  final number = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  if (symbol.isEmpty) return '$number$perMonth';
  if (priceString.trim().startsWith(symbol)) {
    final spaced = priceString.trim().startsWith('$symbol ');
    return '$symbol${spaced ? ' ' : ''}$number$perMonth';
  }
  return '$number $symbol$perMonth';
}

/// The paywall's three-step trial timeline, from the trial's length.
/// [price] is the store's price string, [suffix] "/month" or "/year".
List<({String day, String detail})> trialTimeline(
  int days,
  String price,
  String suffix, [
  AppLocalizations? l10n,
]) {
  l10n ??= currentL10n();
  final reminderDay = days - 2;
  return [
    (day: l10n.paywallTimelineToday, detail: l10n.paywallTimelineTodayDetail),
    if (reminderDay >= 1)
      (
        day: l10n.paywallTimelineDay(reminderDay),
        detail: l10n.paywallTimelineReminderDetail,
      ),
    (
      day: l10n.paywallTimelineDay(days),
      detail: l10n.paywallTimelineChargeDetail('$price$suffix'),
    ),
  ];
}
