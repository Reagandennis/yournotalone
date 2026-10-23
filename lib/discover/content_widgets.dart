import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import 'content_index.dart';

/// Small "New" badge for content that shipped in the last few weeks.
class NewChip extends StatelessWidget {
  const NewChip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.tint(Pillars.red, 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'New',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: c.accent(Pillars.red),
        ),
      ),
    );
  }
}

/// One item as a full-width row: icon, title with its badges, and the
/// meta line. Tapping opens it through [openContent].
class ContentRow extends StatelessWidget {
  const ContentRow({super.key, required this.item, required this.source});

  final ContentItem item;
  final String source;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final locked = item.premium && !isPremiumUser();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.border, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openContent(context, item, source: source),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.tint(item.accent, 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: c.accent(item.accent),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.ink,
                              ),
                            ),
                          ),
                          if (item.isNewAt(DateTime.now())) ...[
                            const SizedBox(width: 6),
                            const NewChip(),
                          ],
                          if (locked) ...[
                            const SizedBox(width: 6),
                            const PremiumChip(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One item as a compact card, for the horizontal strips on Home.
class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.item,
    required this.source,
    this.width = 168,
  });

  final ContentItem item;
  final String source;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final locked = item.premium && !isPremiumUser();
    return SizedBox(
      width: width,
      child: Material(
        color: c.tint(item.accent, 0.07),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openContent(context, item, source: source),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c.chip,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.icon,
                        size: 17,
                        color: c.accent(item.accent),
                      ),
                    ),
                    const Spacer(),
                    // The full chip doesn't fit beside the icon on a
                    // narrow card at larger text sizes; the lock does.
                    if (locked)
                      Semantics(
                        label: 'Premium',
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: c.tint(Pillars.yellow, 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: c.ink,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal strip of [ContentCard]s whose height follows the text
/// scale, so larger system text doesn't clip the cards.
class ContentStrip extends StatelessWidget {
  const ContentStrip({super.key, required this.items, required this.source});

  final List<ContentItem> items;
  final String source;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: 76 + 62 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) =>
            ContentCard(item: items[i], source: source),
      ),
    );
  }
}

/// A selectable pill, for need and length filters.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color = Pillars.blue,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Material(
      color: selected ? c.ink : c.tint(color, 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? c.onInk : c.accent(color),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? c.onInk : c.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full list of index items with length filters: what a need, a
/// collection, or "see all" opens.
class ContentListScreen extends StatefulWidget {
  const ContentListScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.source,
  });

  /// Everything that answers [need], best match first.
  factory ContentListScreen.forNeed(Need need) => ContentListScreen(
    title: need.label,
    subtitle: _needIntro[need]!,
    // Free first, otherwise in catalogue order. Two passes rather than a
    // sort, which in Dart isn't guaranteed to keep that order.
    items: [
      for (final item in contentIndex)
        if (item.needs.contains(need) && !item.premium) item,
      for (final item in contentIndex)
        if (item.needs.contains(need) && item.premium) item,
    ],
    source: 'need:${need.name}',
  );

  final String title;
  final String subtitle;
  final List<ContentItem> items;
  final String source;

  static Route<void> route(ContentListScreen screen) =>
      MaterialPageRoute(builder: (_) => screen);

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

const _needIntro = {
  Need.sleep: 'For the evening before, and the hours you\'re lying awake.',
  Need.anxious: 'Ways to bring a racing mind back to what\'s in front of you.',
  Need.panic: 'Quick and simple first. These work best started straight away.',
  Need.low:
      'Small, kind things for heavy days. Start with whichever feels '
      'doable.',
  Need.stressed: 'Bring the body down first, then sort what\'s on your plate.',
  Need.angry: 'Let it cool before you act on it.',
  Need.urges: 'Ride it out: urges peak and pass, usually within minutes.',
  Need.focus: 'Clear your head and settle into one thing.',
  Need.reflect: 'Prompts and reads for making sense of things.',
  Need.good: 'Notice what\'s going right, so it stays with you.',
};

class _ContentListScreenState extends State<ContentListScreen> {
  var _length = LengthFilter.any;

  @override
  Widget build(BuildContext context) =>
      PremiumBuilder(builder: (context, _) => _page(context));

  Widget _page(BuildContext context) {
    final c = context.brand;
    // Only offer the length filters that would leave something to show.
    final lengths = [
      for (final f in LengthFilter.values)
        if (f == LengthFilter.any ||
            widget.items.any((i) => f.matches(i.minutes)))
          f,
    ];
    final shown = [
      for (final item in widget.items)
        if (_length.matches(item.minutes)) item,
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                const Align(alignment: Alignment.centerLeft, child: BackChip()),
                const SizedBox(height: 20),
                Text(
                  widget.title,
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
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  countLine(widget.items),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.textMuted,
                  ),
                ),
                if (lengths.length > 2) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in lengths)
                        FilterPill(
                          label: f.label,
                          selected: _length == f,
                          onTap: () => setState(() => _length = f),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'Nothing that length yet.',
                      style: TextStyle(color: c.textMuted, fontSize: 14),
                    ),
                  )
                else
                  for (final item in shown)
                    ContentRow(item: item, source: widget.source),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
