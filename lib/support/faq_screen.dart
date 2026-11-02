import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../legal/legal_content.dart';

class _FaqItem {
  const _FaqItem(this.question, this.answer);

  final String question;
  final String answer;
}

class _FaqSection {
  const _FaqSection(this.title, this.items);

  final String title;
  final List<_FaqItem> items;
}

/// Only the store this device buys from: App Review rejects iPhone apps
/// that point people at Google Play, and the reverse reads oddly too.
bool get _onApple =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;
/// Picks the store's wording in the store-specific answers.
String get _store => _onApple ? 'apple' : 'google';

List<_FaqSection> _sections(AppLocalizations l10n) => [
  _FaqSection(l10n.faqSectionUsingApp, [
    _FaqItem(l10n.faqWhatIsQ, l10n.faqWhatIsA),
    _FaqItem(l10n.faqSubstituteQ, l10n.faqSubstituteA),
    _FaqItem(l10n.faqRemindersQ, l10n.faqRemindersA),
  ]),
  _FaqSection(l10n.faqSectionBilling, [
    _FaqItem(l10n.faqPremiumQ, l10n.faqPremiumA),
    _FaqItem(l10n.faqCancelSubQ, l10n.faqCancelSubA(_store)),
    _FaqItem(l10n.faqWrongPlanQ, l10n.faqWrongPlanA(_store)),
    _FaqItem(l10n.faqRefundQ, l10n.faqRefundA(_store)),
  ]),
  _FaqSection(l10n.faqSectionTherapy, [
    _FaqItem(l10n.faqBookQ, l10n.faqBookA),
    _FaqItem(l10n.faqCostQ, l10n.faqCostA),
    _FaqItem(l10n.faqMoveQ, l10n.faqMoveA),
    _FaqItem(l10n.faqHowSessionsQ, l10n.faqHowSessionsA),
    _FaqItem(l10n.faqRemindedQ, l10n.faqRemindedA),
    _FaqItem(l10n.faqCancelSessionQ, l10n.faqCancelSessionA),
    _FaqItem(l10n.faqWhoQ, l10n.faqWhoA),
    _FaqItem(l10n.faqRateQ, l10n.faqRateA),
  ]),
  _FaqSection(l10n.faqSectionPrivacy, [
    _FaqItem(l10n.faqJournalQ, l10n.faqJournalA),
    _FaqItem(l10n.faqSellDataQ, l10n.faqSellDataA),
    _FaqItem(l10n.faqDeleteQ, l10n.faqDeleteA),
  ]),
  _FaqSection(l10n.faqSectionAccount, [
    _FaqItem(l10n.faqProfileQ, l10n.faqProfileA),
    _FaqItem(l10n.faqPasswordQ, l10n.faqPasswordA),
  ]),
];

/// FAQ: grouped, expandable questions, with a contact card at the end.
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: legalContactEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.faqEmailCopied)),
      );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 22, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.brand.textMuted,
        ),
      ),
    );
  }

  Widget _item(BuildContext context, _FaqItem item) {
    final c = context.brand;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border, width: 1.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: c.textMuted,
        collapsedIconColor: c.textMuted,
        title: Text(
          item.question,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.ink,
            height: 1.4,
          ),
        ),
        children: [
          Text(
            item.answer,
            style: TextStyle(
              fontSize: 13,
              color: c.textMuted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard(BuildContext context) {
    final c = context.brand;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.tint(Pillars.blue, 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        onTap: () => _copyEmail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.chip,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mail_outline_rounded,
                  size: 22,
                  color: c.blue,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.faqStillNeedHelp,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.faqWriteToUs(legalContactEmail),
                      style: TextStyle(
                        fontSize: 12.5,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.faqTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
              children: [
                const PillarStripe(),
                const SizedBox(height: 14),
                Text(
                  l10n.faqIntro,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: c.textMuted,
                    height: 1.55,
                  ),
                ),
                for (final section in _sections(l10n)) ...[
                  _sectionLabel(context, section.title),
                  for (final item in section.items) _item(context, item),
                ],
                _contactCard(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
