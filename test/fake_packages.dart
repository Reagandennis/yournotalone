import 'package:purchases_flutter/purchases_flutter.dart';

/// The Play offering as RevenueCat would hand it over: monthly with a
/// 7-day trial, yearly with a 1-month trial, priced in Ksh.
List<Package> fakePackages() {
  const context = PresentedOfferingContext('default', null, null);
  return [
    const Package(
      '\$rc_monthly',
      PackageType.monthly,
      StoreProduct(
        'premium:monthly',
        'Premium, monthly',
        'Premium monthly',
        1500,
        'Ksh 1,500.00',
        'KES',
        introductoryPrice: IntroductoryPrice(
          0,
          'Free',
          'P1W',
          1,
          PeriodUnit.day,
          7,
        ),
      ),
      context,
    ),
    const Package(
      '\$rc_annual',
      PackageType.annual,
      StoreProduct(
        'premium:yearly',
        'Premium, yearly',
        'Premium yearly',
        9000,
        'Ksh 9,000.00',
        'KES',
        introductoryPrice: IntroductoryPrice(
          0,
          'Free',
          'P1M',
          1,
          PeriodUnit.month,
          1,
        ),
      ),
      context,
    ),
  ];
}
