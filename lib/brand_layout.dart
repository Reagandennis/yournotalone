import 'package:flutter/material.dart';

/// A full-height column that starts scrolling when it doesn't fit.
///
/// The session and player screens are designed to fill the screen —
/// `Spacer`s push the controls to the bottom and the artwork to the
/// middle. That works beautifully at 844 points tall and overflows at
/// 568, which is a phone plenty of people still carry, and overflows
/// sooner again when system text is scaled up.
///
/// This keeps the roomy layout when there is room, and turns into an
/// ordinary scroll view when there isn't. `IntrinsicHeight` is what lets
/// `Spacer` and `Expanded` keep working inside a scroll view: the column
/// takes its natural height, and the constraint below stretches it to the
/// viewport whenever the viewport is the larger of the two.
class FlexibleColumn extends StatelessWidget {
  const FlexibleColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: crossAxisAlignment,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

/// The widest a column of reading content gets on a tablet.
///
/// Every screen here was designed for a phone. Stretched across an iPad —
/// 1024 points wide in portrait, 1366 in landscape — cards turn into
/// banners, line lengths double and buttons span the whole display. Below
/// this width (every phone, and iPad Slide Over / narrow Split View) the
/// layout is exactly what it was; above it, content stops growing and is
/// centred, with the screen's background and app bar still running
/// edge to edge.
const double kReadableMaxWidth = 640;

/// Centres [child] and caps its width at [maxWidth] — a no-op on phones.
///
/// Wrap a screen's scrolling body in this rather than the whole screen, so
/// app bars, header bands and backgrounds stay full-bleed.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    this.maxWidth = kReadableMaxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // heightFactor 1: as tall as the child, so this also works where the
    // height is unbounded (a bottom bar), while a scroll view or column
    // inside still fills the height it is given.
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// The widest a screen of cards gets: hubs, lists and the main tabs.
///
/// Above [kReadableMaxWidth] these screens don't stretch their cards; they
/// lay them out in columns ([CardGrid]) up to this width, so an iPad or an
/// open iPhone Duo shows more at once instead of a phone column with wide
/// empty margins. Reading and form screens keep [kReadableMaxWidth].
const double kWideMaxWidth = 1120;

/// Whether there's room for the side navigation and two-column pages:
/// an iPad, an open iPhone Duo, a large Android tablet or foldable, or a
/// phone on its side.
///
/// Decided by the width the app has, never by the device, because the
/// same app moves between widths: an iPhone Duo folds and unfolds, and
/// iPad windows can be resized at any time.
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 600;

/// [children] in as many columns as fit [minTileWidth] each, up to
/// [maxColumns]; one column — exactly the phone layout — when only one fits.
///
/// Cards in a row are stretched to the tallest one, so a row reads as a
/// row. Each child keeps its own bottom spacing, so the same card widgets
/// work in both layouts.
class CardGrid extends StatelessWidget {
  const CardGrid({
    super.key,
    required this.children,
    this.minTileWidth = 320,
    this.maxColumns = 3,
    this.spacing = 16,
    this.equalHeights = true,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  /// Off for children that can't report an intrinsic height (anything
  /// holding a LayoutBuilder or a scroll view).
  final bool equalHeights;

  /// How many columns of [minTileWidth] fit [width].
  static int columnsFor(
    double width, {
    double minTileWidth = 320,
    int maxColumns = 3,
    double spacing = 16,
  }) => ((width + spacing) / (minTileWidth + spacing)).floor().clamp(
    1,
    maxColumns,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.maxWidth,
          minTileWidth: minTileWidth,
          maxColumns: maxColumns,
          spacing: spacing,
        );
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i += columns)
              _row([
                for (var j = i; j < i + columns; j++)
                  j < children.length ? children[j] : const SizedBox.shrink(),
              ]),
          ],
        );
      },
    );
  }

  Widget _row(List<Widget> cells) {
    final row = Row(
      crossAxisAlignment: equalHeights
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        for (var k = 0; k < cells.length; k++) ...[
          if (k > 0) SizedBox(width: spacing),
          Expanded(child: cells[k]),
        ],
      ],
    );
    return equalHeights ? IntrinsicHeight(child: row) : row;
  }
}

/// Two columns side by side when there's room for both at [minColumnWidth],
/// else [first] above [second] — the phone order.
class TwoColumns extends StatelessWidget {
  const TwoColumns({
    super.key,
    required this.first,
    required this.second,
    this.minColumnWidth = 380,
    this.spacing = 28,
  });

  final List<Widget> first;
  final List<Widget> second;
  final double minColumnWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < minColumnWidth * 2 + spacing) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...first, ...second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: first,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: second,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Whether the screen is tablet-sized: an iPad, or a large Android tablet,
/// in either orientation. Narrow Split View panes count as phones, because
/// that is the layout that fits them.
bool isTabletLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600;
