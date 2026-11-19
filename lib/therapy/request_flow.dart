/// Asking for a therapy session, one question at a time: what they'd like
/// help with, when they could meet (and anything the therapist should
/// know), then a review with the price before they pay. The therapy screen
/// does the saving and paying ([SessionRequestFlow.onSubmit]); this only
/// asks.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../brand_layout.dart';
import '../l10n/l10n.dart';
import '../legal/legal_content.dart';
import '../support/countries.dart';
import 'therapy_repository.dart';

/// The times a client can say suit them. Stored as written here (the care
/// team and therapist read them), shown in the app's language.
const therapyTimeSlots = [
  'Weekday mornings',
  'Weekday afternoons',
  'Weekday evenings',
  'Weekends',
];

/// A stored time slot as it reads on screen.
String therapySlotLabel(AppLocalizations l10n, String slot) => switch (slot) {
  'Weekday mornings' => l10n.therapySlotWeekdayMornings,
  'Weekday afternoons' => l10n.therapySlotWeekdayAfternoons,
  'Weekday evenings' => l10n.therapySlotWeekdayEvenings,
  'Weekends' => l10n.therapySlotWeekends,
  _ => slot,
};

IconData _slotIcon(String slot) => switch (slot) {
  'Weekday mornings' => Icons.wb_twilight_rounded,
  'Weekday afternoons' => Icons.wb_sunny_rounded,
  'Weekday evenings' => Icons.nightlight_round,
  'Weekends' => Icons.weekend_rounded,
  _ => Icons.schedule_rounded,
};

IconData _topicIcon(String topic) => switch (topic) {
  'Anxiety & stress' => Icons.air_rounded,
  'Low mood' => Icons.cloud_rounded,
  'Relationships' => Icons.people_alt_rounded,
  'Grief & loss' => Icons.local_florist_rounded,
  'Addiction & recovery' => Icons.healing_rounded,
  _ => Icons.help_outline_rounded,
};

/// What someone asked for.
class SessionRequestForm {
  const SessionRequestForm({
    required this.topic,
    this.availability = const [],
    this.note = '',
  });

  final String topic;

  /// In [therapyTimeSlots] order. Empty means any time.
  final List<String> availability;
  final String note;
}

/// The three steps, full screen. Pops with true once the request is on its
/// way (or the therapy screen has something new to show); backing out
/// pops with nothing.
class SessionRequestFlow extends StatefulWidget {
  const SessionRequestFlow({
    super.key,
    required this.quote,
    required this.onSubmit,
  });

  /// The price, by their country. A listenable, so the review shows a
  /// price that changed while the flow was open.
  final ValueListenable<TherapyPriceQuote> quote;

  /// Saves the request and takes the payment. True when the flow should
  /// close: the request is on its way, or the therapy screen now shows it
  /// (a payment still being checked, a price that changed). False keeps
  /// the review open to try again.
  final Future<bool> Function(SessionRequestForm form) onSubmit;

  static Route<bool> route({
    required ValueListenable<TherapyPriceQuote> quote,
    required Future<bool> Function(SessionRequestForm form) onSubmit,
  }) => MaterialPageRoute<bool>(
    settings: const RouteSettings(name: '/therapy/request'),
    builder: (_) => SessionRequestFlow(quote: quote, onSubmit: onSubmit),
  );

  @override
  State<SessionRequestFlow> createState() => _SessionRequestFlowState();
}

class _SessionRequestFlowState extends State<SessionRequestFlow> {
  static const _steps = 3;

  int _step = 0;
  String? _topic;
  final _slots = <String>{};
  final _note = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_step) {
    0 => _topic != null,
    _ => true,
  };

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  Future<void> _submit() async {
    final topic = _topic;
    if (topic == null || _submitting) return;
    setState(() => _submitting = true);
    final done = await widget.onSubmit(
      SessionRequestForm(
        topic: topic,
        availability: [
          for (final slot in therapyTimeSlots)
            if (_slots.contains(slot)) slot,
        ],
        note: _note.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (done) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    return PopScope(
      // Back steps back through the questions before it leaves.
      canPop: _step == 0 && !_submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0 && !_submitting) _goTo(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
            ),
            tooltip: _step == 0 ? l10n.commonClose : l10n.commonBack,
            onPressed: _submitting
                ? null
                : () => _step == 0
                      ? Navigator.of(context).maybePop()
                      : _goTo(_step - 1),
          ),
          title: Text(l10n.therapyFlowTitle),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30),
            child: ReadableWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 10),
                child: _Progress(step: _step, of: _steps),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: ReadableWidth(
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                        children: switch (_step) {
                          0 => _topicStep(),
                          1 => _whenStep(),
                          _ => _reviewStep(),
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: _step < _steps - 1
                      ? ElevatedButton(
                          onPressed: _canContinue
                              ? () => _goTo(_step + 1)
                              : null,
                          child: Text(l10n.commonContinue),
                        )
                      : ValueListenableBuilder<TherapyPriceQuote>(
                          valueListenable: widget.quote,
                          builder: (context, quote, _) => ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(l10n.therapyFlowPay(quote.priceLabel)),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: what would you like help with? ──

  List<Widget> _topicStep() {
    final l10n = context.l10n;
    return [
      _StepHeading(
        title: l10n.therapyFocusQuestion,
        hint: l10n.therapyFlowTopicHint,
      ),
      for (final topic in therapyTopics)
        _OptionTile(
          icon: _topicIcon(topic),
          label: therapyTopicLabel(l10n, topic),
          selected: _topic == topic,
          single: true,
          onTap: () => setState(() => _topic = topic),
        ),
    ];
  }

  // ── Step 2: when, and anything to know ──

  List<Widget> _whenStep() {
    final l10n = context.l10n;
    final c = context.brand;
    return [
      _StepHeading(
        title: l10n.therapyWhenQuestion,
        hint: l10n.therapyFlowWhenHint,
      ),
      for (final slot in therapyTimeSlots)
        _OptionTile(
          icon: _slotIcon(slot),
          label: therapySlotLabel(l10n, slot),
          selected: _slots.contains(slot),
          single: false,
          onTap: () => setState(() {
            _slots.contains(slot) ? _slots.remove(slot) : _slots.add(slot);
          }),
        ),
      const SizedBox(height: 20),
      // The question sits above the box, where it can wrap: as a floating
      // label it's cut short on a phone.
      Text(
        l10n.therapyNoteLabel,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.ink,
          height: 1.35,
        ),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _note,
        maxLines: 4,
        minLines: 3,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          // Stays in view while they type, unlike a hint.
          helperText: l10n.therapyFlowNoteHint,
          helperMaxLines: 2,
          helperStyle: TextStyle(fontSize: 12, color: c.textMuted),
        ),
      ),
    ];
  }

  // ── Step 3: check and pay ──

  List<Widget> _reviewStep() {
    final l10n = context.l10n;
    final c = context.brand;
    final topic = _topic;
    final times = [
      for (final slot in therapyTimeSlots)
        if (_slots.contains(slot)) therapySlotLabel(l10n, slot),
    ];
    final note = _note.text.trim();
    return [
      _StepHeading(title: l10n.therapyFlowReviewTitle),
      _Panel(
        child: Column(
          children: [
            _SummaryRow(
              label: l10n.therapyFlowFocus,
              value: topic == null ? '' : therapyTopicLabel(l10n, topic),
              onChange: _submitting ? null : () => _goTo(0),
            ),
            Divider(height: 1, color: c.border),
            _SummaryRow(
              label: l10n.therapyFlowTimes,
              value: times.isEmpty ? l10n.therapyFlowAnyTime : times.join(', '),
              onChange: _submitting ? null : () => _goTo(1),
            ),
            if (note.isNotEmpty) ...[
              Divider(height: 1, color: c.border),
              _SummaryRow(
                label: l10n.therapyFlowNote,
                value: note,
                maxLines: 3,
                onChange: _submitting ? null : () => _goTo(1),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      ValueListenableBuilder<TherapyPriceQuote>(
        valueListenable: widget.quote,
        builder: (context, quote, _) => TherapyPriceSummary(quote: quote),
      ),
      const SizedBox(height: 22),
      Text(
        l10n.therapyFlowNextTitle,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.ink,
        ),
      ),
      const SizedBox(height: 10),
      _NextStep(
        icon: Icons.mark_email_read_rounded,
        text: l10n.therapyFlowNextMatch,
      ),
      _NextStep(icon: Icons.videocam_rounded, text: l10n.therapyFlowNextJoin),
      const SizedBox(height: 14),
      Text(
        l10n.therapyCancellationPolicy,
        style: TextStyle(fontSize: 12.5, color: c.textMuted, height: 1.5),
      ),
    ];
  }
}

/// The price as the review shows it: what a session is, what it costs,
/// where that price comes from, and what Paystack will charge when that's
/// a different currency.
class TherapyPriceSummary extends StatelessWidget {
  const TherapyPriceSummary({super.key, required this.quote});

  final TherapyPriceQuote quote;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final convertsCurrency =
        quote.chargeCurrency.toUpperCase() != quote.currency.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.tint(Pillars.blue, 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote.priceLabel,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: c.ink,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.therapySessionWhat,
            style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.45),
          ),
          const SizedBox(height: 10),
          PriceCountryLine(quote: quote),
          if (convertsCurrency) ...[
            const SizedBox(height: 10),
            Text(
              l10n.therapyFlowChargeNote(quote.chargeLabel),
              style: TextStyle(fontSize: 12.5, color: c.textMuted, height: 1.5),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            l10n.therapyPaysVia(l10n.therapyPaymentMethods),
            style: TextStyle(fontSize: 12.5, color: c.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// "Prices for Kenya, from your Google Play account · Not right?", or, when
/// they may pick their country here (before one is detected), "· Change".
/// Nothing for the stand-in price, which isn't anyone's country.
class PriceCountryLine extends StatelessWidget {
  const PriceCountryLine({
    super.key,
    required this.quote,
    this.onChange,
    this.changing = false,
  });

  final TherapyPriceQuote quote;

  /// Opens the country list. Shown only while [TherapyPriceQuote.canChange].
  final VoidCallback? onChange;
  final bool changing;

  @override
  Widget build(BuildContext context) {
    final country = quote.country;
    if (!quote.fromServer || (country == null && !quote.canChange)) {
      return const SizedBox.shrink();
    }
    final c = context.brand;
    final l10n = context.l10n;
    final style = TextStyle(fontSize: 12.5, color: c.textMuted, height: 1.4);
    final name = country == null ? null : countryName(country);
    final text = switch ((name, quote.source)) {
      (null, _) => l10n.therapyPricesNoCountry,
      (final n?, 'store') when !quote.locked => l10n.therapyPricesFromStore(
        n,
        _storeName(),
      ),
      (final n?, 'sim') when !quote.locked => l10n.therapyPricesFromSim(n),
      (final n?, 'zone') when !quote.locked => l10n.therapyPricesFromZone(n),
      (final n?, 'region') when !quote.locked => l10n.therapyPricesFromRegion(
        n,
      ),
      (final n?, _) => l10n.therapyPricesFor(n),
    };
    final canPick = quote.canChange && onChange != null;
    return Row(
      children: [
        Icon(Icons.public_rounded, size: 15, color: c.textMuted),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: style)),
        const SizedBox(width: 6),
        TextButton(
          onPressed: changing
              ? null
              : canPick
              ? onChange
              : () => showCountryHelp(context, quote),
          // Only the spacing changes: the theme's font stays.
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
          ),
          child: changing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  canPick
                      ? l10n.therapyPriceCountryChange
                      : l10n.therapyPriceCountryWrong,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

/// "App Store" or "Google Play": not translated, they're names.
String _storeName() =>
    defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS
    ? 'App Store'
    : 'Google Play';

/// Why the price is for this country, and how to have it changed: by
/// writing to us, since the country comes from where their phone is (or is
/// fixed by their first payment) rather than a list anyone could pick from.
Future<void> showCountryHelp(BuildContext context, TherapyPriceQuote quote) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final c = sheetContext.brand;
      final l10n = sheetContext.l10n;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.therapyCountryHelpTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                quote.locked
                    ? l10n.therapyCountryHelpLocked
                    : l10n.therapyCountryHelpBody(_storeName()),
                style: TextStyle(
                  fontSize: 14,
                  color: c.textMuted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _emailUs(context, quote);
                },
                child: Text(l10n.therapyCountryHelpEmail),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _emailUs(BuildContext context, TherapyPriceQuote quote) async {
  final uri = Uri(
    scheme: 'mailto',
    path: legalContactEmail,
    queryParameters: {
      'subject': 'My country for session prices',
      'body':
          'Prices are set for ${quote.country == null ? 'no country' : countryName(quote.country!)}, '
          'but I live in: ',
    },
  );
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    throw Exception('no mail app');
  } catch (_) {
    // No mail app: hand over the address instead.
    await Clipboard.setData(const ClipboardData(text: legalContactEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.settingsEmailCopied(legalContactEmail)),
      ),
    );
  }
}

// ── Pieces ──

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.of});

  final int step;
  final int of;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    return Semantics(
      label: l10n.therapyFlowStep(step + 1, of),
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < of; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? c.ink : c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
            Text(
              l10n.therapyFlowStep(step + 1, of),
              style: TextStyle(fontSize: 12, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: c.ink,
                height: 1.25,
              ),
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint!,
              style: TextStyle(fontSize: 14, color: c.textMuted, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// A large, tappable choice: a radio when [single], else a checkbox.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.single,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool single;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final mark = single
        ? (selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded)
        : (selected
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: single,
        checked: single ? null : selected,
        button: true,
        child: Material(
          color: selected ? c.tint(Pillars.black, 0.04) : c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? c.ink : c.border,
              width: selected ? 1.6 : 1.2,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.tint(Pillars.blue, 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: c.blue),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: c.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ExcludeSemantics(
                    child: Icon(
                      mark,
                      size: 22,
                      color: selected ? c.ink : c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.onChange,
    this.maxLines = 2,
  });

  final String label;
  final String value;
  final VoidCallback? onChange;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: c.textMuted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: c.ink,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(
              l10n.therapyFlowEdit,
              semanticsLabel: '${l10n.therapyFlowEdit}: $label',
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
