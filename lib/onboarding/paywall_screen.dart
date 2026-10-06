import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../auth/auth_ui.dart';
import '../billing/paywall_copy.dart';
import '../billing/pricing_copy.dart';
import '../billing/purchases_service.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../home/mood_face.dart';
import '../home/mood_scale.dart';
import '../legal/legal_content.dart';
import '../legal/legal_screen.dart';
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
// sold as Premium. The first three rows are the ones that differ most,
// because only those show until "See everything" is tapped.
const _rows = [
  _PlanRow('Guided meditations & breathing', '2 free', 'All 20'),
  _PlanRow('Journaling', '5 entries', 'Unlimited'),
  _PlanRow('Mood history & progress', null, _PlanRow.included),
  _PlanRow('Wellbeing sounds — focus, sleep, calm', '1 free', 'All 13'),
  _PlanRow('Journal prompts', '1 free', 'All 19'),
  _PlanRow('Recovery tracking & insights', null, _PlanRow.included),
  _PlanRow('Daily mood check-ins', _PlanRow.included, _PlanRow.included),
  _PlanRow('Daily reminders', _PlanRow.included, _PlanRow.included),
  _PlanRow('Urge surfing, any time', _PlanRow.included, _PlanRow.included),
];

const _rowsShownFolded = 3;

/// Premium paywall shown at the end of onboarding and from upgrade
/// prompts. Sells the RevenueCat offering (weekly / monthly / yearly);
/// when the store isn't reachable it falls back to a static preview.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.checkin,
    this.fromOnboarding = false,
    this.extraData = const {},
    this.source = 'settings',
    this.packages,
  });

  /// The wellbeing check-in answer: saved when onboarding completes, and
  /// what the headline speaks to.
  final String checkin;

  /// True only on the last step of onboarding. When false — an upgrade from
  /// Settings or an upgrade sheet — finishing pops back to where the user
  /// was instead of resetting them to a fresh Home tab.
  final bool fromOnboarding;

  /// Answers gathered earlier in onboarding that still need saving with the
  /// rest (the therapy offer collects some before this screen).
  final Map<String, dynamic> extraData;

  /// Where this view came from ("onboarding", "settings", "sheet:sounds",
  /// "nudge:mood3"), so the funnel can be read per entry point.
  final String source;

  /// Injectable so the plan picker and trial timeline can be exercised
  /// without a store. Null means ask RevenueCat.
  final List<Package>? packages;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = false;

  /// Until the store has said whether this account already has Premium,
  /// the buy button waits. On a device someone has just signed in to, the
  /// answer arrives a moment after sign-in; selling them a trial in that
  /// moment ends in Play's "already owned" error.
  bool _checking = true;

  /// Set once this screen has decided how it ends, so a purchase, a
  /// restore and the entitlement listener can't each finish it.
  bool _done = false;

  bool _expanded = false;
  List<Package> _packages = const [];
  Package? _selected;

  @override
  void initState() {
    super.initState();
    _metric('paywall.shown');
    PurchasesService.instance.isPro.addListener(_onEntitlement);
    _check();
  }

  @override
  void dispose() {
    PurchasesService.instance.isPro.removeListener(_onEntitlement);
    super.dispose();
  }

  void _metric(String name, {String? plan, bool? trial}) {
    Sentry.metrics.count(name, 1, attributes: {
      'source': SentryAttribute.string(widget.source),
      'checkin': SentryAttribute.string(widget.checkin),
      if (plan != null) 'plan': SentryAttribute.string(plan),
      if (trial != null) 'trial': SentryAttribute.string(trial ? 'yes' : 'no'),
    });
  }

  /// Nobody is sold Premium who already has it.
  Future<void> _check() async {
    final pro = await PurchasesService.instance.refreshEntitlement();
    if (!mounted) return;
    if (pro || isPremiumUser()) {
      await _alreadyPremium();
      return;
    }
    setState(() => _checking = false);
    await _loadOffering();
  }

  /// The entitlement can land while this screen is open — RevenueCat
  /// finishing the sign-in switch, or a purchase made on another device.
  /// A purchase or restore made here reports its own result instead.
  void _onEntitlement() {
    if (PurchasesService.instance.isPro.value && !_loading) {
      _alreadyPremium();
    }
  }

  Future<void> _alreadyPremium() async {
    if (_done || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You already have Premium — everything is unlocked.'),
      ),
    );
    await _finish('premium');
  }

  Future<void> _loadOffering() async {
    final List<Package> ordered;
    if (widget.packages != null) {
      ordered = widget.packages!;
    } else {
      final offering = await PurchasesService.instance.currentOffering();
      if (!mounted || offering == null) return;
      ordered = [
        offering.weekly,
        offering.monthly,
        offering.annual,
      ].whereType<Package>().toList();
    }
    final preferred = preferredPlan(widget.checkin);
    setState(() {
      _packages = ordered;
      _selected = ordered.isEmpty
          ? null
          : ordered.firstWhere(
              (p) => p.packageType == preferred,
              orElse: () => ordered.last,
            );
    });
  }

  /// Saves the choice and leaves. During onboarding that means handing over
  /// to Home; afterwards it means going back to whatever the user was doing
  /// when they decided to upgrade.
  Future<void> _finish(String planChoice) async {
    if (_done) return;
    _done = true;
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
    _metric('paywall.dismissed');
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
        _metric(
          'paywall.purchased',
          plan: package.packageType.name,
          trial: trialDays(package) != null,
        );
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
      if (isAlreadyOwnedError(e)) {
        // The store account already subscribes — typically a subscriber
        // on a new device whose entitlement hadn't loaded yet. Attach the
        // subscription to this account rather than report a failure.
        try {
          if (await PurchasesService.instance.restore() && mounted) {
            await _finish('premium');
            return;
          }
        } catch (restoreError) {
          debugPrint('Restore after already-owned failed: $restoreError');
        }
      }
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
        _metric('paywall.restored');
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
        PackageType.weekly => 'Weekly',
        PackageType.monthly => 'Monthly',
        PackageType.annual => 'Yearly',
        _ => p.storeProduct.title,
      };

  String _packageNote(Package p) => switch (p.packageType) {
        PackageType.weekly => 'per week',
        PackageType.monthly => 'per month',
        PackageType.annual => 'per year',
        _ => '',
      };

  String _periodSuffix(Package p) => switch (p.packageType) {
        PackageType.weekly => '/week',
        PackageType.monthly => '/month',
        PackageType.annual => '/year',
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

  Widget _faces() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (i, level) in moodLevels.indexed) ...[
          if (i != 0) const SizedBox(width: 10),
          MoodFace(level: level, size: 40),
        ],
      ],
    );
  }

  Widget _trust() {
    final c = context.brand;
    const items = ['Licensed therapists', 'Private by design', 'Cancel anytime'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: c.card,
              border: Border.all(color: c.border, width: 1.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 14, color: c.blue),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _planPicker() {
    final c = context.brand;
    final savings = _savingsPercent;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, p) in _packages.indexed) ...[
            if (i != 0) const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: _selected == p ? c.tint(Pillars.black, 0.04) : c.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _selected == p ? c.ink : c.border,
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
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.storeProduct.priceString,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.packageType == PackageType.annual
                              ? perMonthLabel(p)
                              : _packageNote(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: c.textMuted,
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
                              color: c.tint(Pillars.yellow, 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SAVE $savings%',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: c.ink,
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

  /// How the trial goes, day by day, so nobody has to wonder when the
  /// charge lands. The day-N-minus-two reminder is a real notification,
  /// scheduled by TrialReminder once the trial is active.
  Widget _timeline(Package p, int days) {
    final steps = trialTimeline(
      days,
      p.storeProduct.priceString,
      _periodSuffix(p),
    );
    final c = context.brand;
    const accents = [Pillars.red, Pillars.blue, Pillars.yellow];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: c.tint(Pillars.black, 0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (final (i, step) in steps.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 22,
                    child: Column(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            color: c.art(accents[i % accents.length]),
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i != steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              color: c.border,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.day,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: c.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            step.detail,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(String? value, {required bool premium}) {
    final c = context.brand;
    final color = premium ? c.ink : c.textMuted;
    if (value == null) {
      return Icon(Icons.remove_rounded, size: 18, color: c.border);
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

  List<Widget> _table() {
    final c = context.brand;
    final rows = _expanded ? _rows : _rows.take(_rowsShownFolded).toList();
    return [
      Row(
        children: [
          const Expanded(child: SizedBox()),
          SizedBox(
            width: 64,
            child: Text(
              'Free',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textMuted,
              ),
            ),
          ),
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: c.tint(Pillars.black, 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Premium',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      for (final (i, row) in rows.indexed) ...[
        if (i != 0) Divider(height: 1, color: c.border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.ink,
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
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          icon: Icon(
            _expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 18,
          ),
          label: Text(_expanded ? 'Show less' : 'See everything'),
        ),
      ),
    ];
  }

  /// The App Store requires the terms and privacy policy to be one tap
  /// away wherever a subscription is sold (guideline 3.1.2).
  Widget _legalLinks() {
    final c = context.brand;
    Widget link(String label, LegalDoc doc) => TextButton(
          key: ValueKey('paywall-legal-${doc.title}'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => LegalScreen(doc: doc)),
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundColor: c.textMuted,
            textStyle: const TextStyle(
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
          child: Text(label),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        link('Terms of Use', termsOfService),
        Text('·', style: TextStyle(color: c.textMuted)),
        link('Privacy Policy', privacyPolicy),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final copy = paywallCopy(widget.checkin);
    final selected = _selected;
    final trial = selected == null ? null : trialLabel(selected);
    final days = selected == null ? null : trialDays(selected);
    return OnboardingScaffold(
      dismissible: !widget.fromOnboarding,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthSubmitButton(
            label: selected != null
                ? (trial != null
                    ? 'Try free for $trial'
                    : 'Start Premium — ${selected.storeProduct.priceString}')
                : 'Start Premium',
            loading: _loading || _checking,
            onPressed: _buy,
          ),
          const SizedBox(height: 4),
          Text(
            selected != null
                ? '${trial != null ? 'then ' : ''}'
                    '${selected.storeProduct.priceString}'
                    '${_periodSuffix(selected)} · cancel anytime'
                : 'Cancel anytime',
            style: TextStyle(fontSize: 12, color: c.textMuted),
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
              Text(
                '·',
                style: TextStyle(color: c.textMuted),
              ),
              TextButton(
                onPressed: _loading ? null : _restore,
                child: const Text('Restore purchases'),
              ),
            ],
          ),
          _legalLinks(),
        ],
      ),
      children: [
        _faces(),
        const SizedBox(height: 18),
        Text(
          copy.headline,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: c.ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const PillarStripe(),
        const SizedBox(height: 14),
        Text(
          copy.detail,
          style: TextStyle(
            fontSize: 14,
            color: c.textMuted,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 16),
        _trust(),
        if (_packages.isNotEmpty) ...[
          const SizedBox(height: 22),
          _planPicker(),
        ] else ...[
          const SizedBox(height: 22),
          Text(
            introOfferSentence,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
        ],
        if (selected != null && days != null) ...[
          const SizedBox(height: 16),
          _timeline(selected, days),
        ],
        const SizedBox(height: 24),
        ..._table(),
        const SizedBox(height: 4),
        Text(
          'Therapy sessions are available to everyone and booked separately.',
          style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.5),
        ),
      ],
    );
  }
}
