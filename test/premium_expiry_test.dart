import 'package:flutter_test/flutter_test.dart';

import 'package:yournotalone/billing/purchases_service.dart';

void main() {
  final ends = DateTime.utc(2026, 12, 1);

  test('premium holds until the paid period ends, online or not', () {
    expect(
      entitlementHolds(
        entitled: true,
        expires: ends,
        now: DateTime.utc(2026, 11, 30),
      ),
      isTrue,
    );
    // RevenueCat's cache still says active, but the period is over.
    expect(
      entitlementHolds(
        entitled: true,
        expires: ends,
        now: DateTime.utc(2026, 12, 31),
      ),
      isFalse,
    );
  });

  test('setting the clock back does not buy more time', () {
    expect(
      entitlementHolds(
        entitled: true,
        expires: ends,
        now: DateTime.utc(2026, 11, 1),
        latestSeen: DateTime.utc(2026, 12, 5),
      ),
      isFalse,
    );
  });

  test('a grant with no end date holds; no entitlement never does', () {
    expect(
      entitlementHolds(entitled: true, expires: null, now: DateTime.utc(2030)),
      isTrue,
    );
    expect(
      entitlementHolds(entitled: false, expires: null, now: DateTime.utc(2026)),
      isFalse,
    );
  });
}
