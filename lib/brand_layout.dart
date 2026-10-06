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

/// Whether the screen is tablet-sized: an iPad, or a large Android tablet,
/// in either orientation. Narrow Split View panes count as phones, because
/// that is the layout that fits them.
bool isTabletLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600;
