import 'package:flutter/material.dart';
import '../billing/pricing_copy.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../auth/auth_ui.dart';
import '../billing/purchases_service.dart';
import '../brand.dart';
import 'onboarding_ui.dart';

class _PlanRow {
  const _PlanRow(this.label, this.free, this.premium);

  final String label;

  /// null → not included; text (e.g. 'Limited') → shown instead of a check.
  final String? free;
  final String? premium;

  static const included = '✓';
}

// Keep this honest: every row here is checked against what the app
// actually gates. Reminders and urge surfing are free, so they are not
// sold as Premium.
const _rows = [
  _PlanRow('Daily mood check-ins', _PlanRow.included, _PlanRow.included),
  _PlanRow('Daily reminders', _PlanRow.included, _PlanRow.included),
  _PlanRow('Urge surfing, any time', _PlanRow.included, _PlanRow.included),
  _PlanRow('Journaling', '5 entries', 'Unlimited'),
  _PlanRow('Guided meditations & breathing', '2 free', 'All 20'),
  _PlanRow('Wellbeing sounds — focus, sleep, calm', '1 free', 'All 13'),
  _PlanRow('Journal prompts', '1 free', 'All 19'),
  _PlanRow('Mood history & progress', null, _PlanRow.included),
  _PlanRow('Recovery tracking & insights', null, _PlanRow.included),
];

/// Premium paywall shown at the end of onboarding and from upgrade
/// prompts. Sells the RevenueCat offering (monthly / yearly);
/// when the store isn't reachable it falls back to a static preview.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.checkin,
    this.fromOnboarding = false,
    this.extraData = const {},
  });

  /// The wellbeing check-in answer, saved when onboarding completes.
  final String checkin;

  /// True only on the last step of onboarding. When false — an upgrade from
  /// Settings or an upgrade sheet — finishing pops back to where the user
  /// was instead of resetting them to a fresh Home tab.
  final bool fromOnboarding;

  /// Answers gathered earlier in onboarding that still need saving with the
  /// rest (the therapy offer collects some before this screen).
  final Map<String, dynamic> extraData;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = false;
  List<Package> _packages = const [];
  Package? _selected;

  @override
  void initState() {
    super.initState();
    _loadOffering();
  }

  Future<void> _loadOffering() async {
    final offering = await PurchasesService.instance.currentOffering();
    if (!mounted || offering == null) return;
    // Sell in this order: monthly first (the intro offer), then bigger
    // commitments.
    final ordered = [
      offering.monthly,
      offering.annual,
    ].whereType<Package>().toList();
    setState(() {
      _packages = ordered;
      _selected = ordered.isEmpty ? null : ordered.first;
    });
  }

  /// Saves the choice and leaves. During onboarding that means handing over
  /// to Home; afterwards it means going back to whatever the user was doing
  /// when they decided to upgrade.
  Future<void> _finish(String planChoice) async {
    final data = {
      ...widget.extraData,
      'wellbeing_checkin': widget.checkin,
      'plan_choice': planChoice,
    };
    if (widget.fromOnboarding) {
      await completeOnboarding(context, data);
    } else {
      await saveOnboardingAnswers(data);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _finishFree() async {
    setState(() => _loading = true);
    // Outside onboarding "maybe later" is just a dismissal — it must not
    // record a downgrade for someone who already pays.
    if (!widget.fromOnboarding) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await _finish('free');
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _buy() async {
    final package = _selected;
    if (package == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchases aren\'t available on this device yet — '
              'you can upgrade later from Settings.'),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final pro = await PurchasesService.instance.purchase(package);
      if (pro && mounted) {
        await _finish('premium');
        return;
      }
      // Purchase went through but the entitlement didn't come back — that's
      // almost always a product↔entitlement mapping gap in RevenueCat.
      debugPrint('Purchase completed but "$proEntitlementId" is not active. '
          'Check the product\'s Associated Entitlements in RevenueCat.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase completed, but premium didn\'t '
                'activate. Try "Restore purchases", or contact support.'),
          ),
        );
      }
    } catch (e) {
      final message = purchaseErrorMessage(e);
      if (message != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _loading = true);
    try {
      final pro = await PurchasesService.instance.restore();
      if (pro && mounted) {
        await _finish('premium');
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous purchases found.')),
        );
      }
    } catch (e) {
      final message = purchaseErrorMessage(e);
      if (message != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _packageName(Package p) => switch (p.packageType) {
        PackageType.monthly => 'Monthly',
        PackageType.annual => 'Yearly',
        _ => p.storeProduct.title,
      };

  String _packageNote(Package p) => switch (p.packageType) {
        PackageType.monthly => 'per month',
        PackageType.annual => 'per year',
        _ => '',
      };

  Package? _byType(PackageType type) {
    for (final p in _packages) {
      if (p.packageType == type) return p;
    }
    return null;
  }

  /// Percent saved by going yearly instead of 12 months of monthly.
  int? get _savingsPercent {
    final monthly = _byType(PackageType.monthly);
    final yearly = _byType(PackageType.annual);
    if (monthly == null || yearly == null) return null;
    final monthlyTotal = monthly.storeProduct.price * 12;
    final yearlyPrice = yearly.storeProduct.price;
    if (monthlyTotal <= 0 || yearlyPrice >= monthlyTotal) return null;
    return ((1 - yearlyPrice / monthlyTotal) * 100).round();
  }

  /// "3 days" / "1 week" when the package starts with a free trial.
  String? _trialLabel(Package p) {
    final intro = p.storeProduct.introductoryPrice;
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

  String _periodSuffix(Package p) => switch (p.packageType) {
        PackageType.monthly => '/month',
        PackageType.annual => '/year',
        _ => '',
      };

  Widget _planPicker() {
    final savings = _savingsPercent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, p) in _packages.indexed) ...[
            if (i != 0) const SizedBox(width: 10),
            Expanded(
              child: Material(
                color:
                    _selected == p ? const Color(0x0A191919) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _selected == p ? Brand.ink : Brand.border,
                    width: _selected == p ? 1.6 : 1.2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _selected = p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 14,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          _packageName(p),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Brand.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.storeProduct.priceString,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Brand.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _packageNote(p),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Brand.textMuted,
                          ),
                        ),
                        if (p.packageType == PackageType.annual &&
                            savings != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x33FAB414),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SAVE $savings%',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: Brand.ink,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(String? value, {required bool premium}) {
    final color = premium ? Brand.ink : Brand.textMuted;
    if (value == null) {
      return Icon(Icons.remove_rounded, size: 18, color: Brand.border);
    }
    if (value == _PlanRow.included) {
      return Icon(Icons.check_rounded, size: 19, color: color);
    }
    return Text(
      value,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: premium ? FontWeight.w600 : FontWeight.w400,
        color: color,
        height: 1.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasStore = _selected != null;
    final trial = hasStore ? _trialLabel(_selected!) : null;
    return OnboardingScaffold(
      dismissible: !widget.fromOnboarding,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthSubmitButton(
            label: hasStore
                ? (trial != null
                    ? 'Try free for $trial'
                    : 'Start Premium — ${_selected!.storeProduct.priceString}')
                : 'Start Premium',
            loading: _loading,
            onPressed: _buy,
          ),
          const SizedBox(height: 4),
          Text(
            hasStore
                ? '${trial != null ? 'then ' : ''}'
                    '${_selected!.storeProduct.priceString}'
                    '${_periodSuffix(_selected!)} · cancel anytime'
                : 'Cancel anytime',
            style: const TextStyle(fontSize: 12, color: Brand.textMuted),
          ),
          const SizedBox(height: 2),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                onPressed: _loading ? null : _finishFree,
                child: Text(widget.fromOnboarding
                    ? 'Continue with Free'
                    : 'Maybe later'),
              ),
              const Text(
                '·',
                style: TextStyle(color: Brand.textMuted),
              ),
              TextButton(
                onPressed: _loading ? null : _restore,
                child: const Text('Restore purchases'),
              ),
            ],
          ),
        ],
      ),
      children: [
        const Text(
          'Go further with Premium',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const PillarStripe(),
        const SizedBox(height: 16),
        const Text(
          'Free gets you started. Premium opens every room in the house — '
          'and $introOffer.',
          style: TextStyle(fontSize: 14, color: Brand.textMuted, height: 1.55),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0x1FFAB414),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  size: 21,
                  color: Brand.yellow,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _packages.any((p) => _trialLabel(p) != null)
                          ? 'Try it free first'
                          : introOfferSentence,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Brand.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _packages.any((p) => _trialLabel(p) != null)
                          ? 'Every plan starts with a free trial'
                              '${_savingsPercent != null ? ' — and yearly saves you $_savingsPercent% vs paying monthly' : ''}. '
                              'Cancel anytime.'
                          : 'Try everything before you pay.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Brand.textMuted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_packages.isNotEmpty) ...[
          const SizedBox(height: 20),
          _planPicker(),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            const SizedBox(
              width: 64,
              child: Text(
                'Free',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Brand.textMuted,
                ),
              ),
            ),
            Container(
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0x14191919),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Premium',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Brand.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final (i, row) in _rows.indexed) ...[
          if (i != 0) const Divider(height: 1, color: Brand.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Brand.ink,
                      height: 1.35,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Center(child: _cell(row.free, premium: false)),
                ),
                SizedBox(
                  width: 76,
                  child: Center(child: _cell(row.premium, premium: true)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Therapy sessions are available to everyone and booked separately.',
          style: TextStyle(fontSize: 12, color: Brand.textMuted, height: 1.5),
        ),
      ],
    );
  }
}
