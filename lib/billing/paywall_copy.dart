import 'package:purchases_flutter/purchases_flutter.dart';

/// What the paywall says to *this* person.
///
/// The onboarding check-in ("steady", "stressed", "struggling",
/// "dark_place") used to be saved at the paywall and never read. It is the
/// one thing the app knows about someone before asking them to pay, so
/// the headline speaks to it instead of to "Premium" in the abstract.
({String headline, String detail}) paywallCopy(String checkin) =>
    switch (checkin) {
      'struggling' || 'dark_place' => (
          headline: 'Support for the hard weeks',
          detail: 'Somewhere to put the day down, every day: guided '
              'meditations for the nights that won\'t settle, a journal '
              'that keeps up, and a record of how the weeks actually go — '
              'so the next hard one is easier to see coming.',
        ),
      'stressed' => (
          headline: 'Somewhere to put it down',
          detail: 'Ten minutes that are yours: breathing for the middle of '
              'a bad afternoon, sounds to fall asleep to, and a journal '
              'that keeps up — with a record of how the weeks actually go.',
        ),
      _ => (
          headline: 'Keep the good days coming',
          detail: 'The habits that keep you steady, all in one place: every '
              'meditation and sound, an unlimited journal, and a record of '
              'how the weeks actually go.',
        ),
    };

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
String? trialLabel(Package package) {
  final intro = package.storeProduct.introductoryPrice;
  if (intro == null || intro.price > 0) return null;
  final unit = switch (intro.periodUnit) {
    PeriodUnit.day => 'day',
    PeriodUnit.week => 'week',
    PeriodUnit.month => 'month',
    PeriodUnit.year => 'year',
    _ => 'day',
  };
  final n = intro.periodNumberOfUnits;
  return n == 1 ? '1 $unit' : '$n ${unit}s';
}

/// A yearly price as "Ksh 750/month", in the store's own currency and
/// symbol placement. The symbol is whatever is left of the store's price
/// string once digits and separators go, so "Ksh 9,000.00" gives "Ksh",
/// "$79.99" gives "$", and the app never hard-codes a currency.
String perMonthLabel(Package yearly) {
  final priceString = yearly.storeProduct.priceString;
  final amount = yearly.storeProduct.price / 12;
  final symbol = priceString.replaceAll(RegExp(r'[\d.,\s]'), '');
  final number = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  if (symbol.isEmpty) return '$number/month';
  if (priceString.trim().startsWith(symbol)) {
    final spaced = priceString.trim().startsWith('$symbol ');
    return '$symbol${spaced ? ' ' : ''}$number/month';
  }
  return '$number $symbol/month';
}

/// The paywall's three-step trial timeline, from the trial's length.
/// [price] is the store's price string, [suffix] "/month" or "/year".
List<({String day, String detail})> trialTimeline(
  int days,
  String price,
  String suffix,
) {
  final reminderDay = days - 2;
  return [
    (day: 'Today', detail: 'Full access to everything in Premium.'),
    if (reminderDay >= 1)
      (
        day: 'Day $reminderDay',
        detail: 'We remind you that the trial is about to end.',
      ),
    (
      day: 'Day $days',
      detail: '$price$suffix starts. Cancel any time before and pay nothing.',
    ),
  ];
}
