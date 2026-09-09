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
