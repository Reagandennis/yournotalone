/// What every toolkit (CBT, sleep, stress) is made of: tools with a screen
/// behind them, short reads, and free resources elsewhere.
library;

import 'package:flutter/material.dart';

import 'toolkit_art.dart';

/// One tool in a toolkit, and the screen that runs it.
class ToolkitTool {
  const ToolkitTool({
    required this.title,
    required this.blurb,
    required this.minutes,
    required this.icon,
    required this.art,
    required this.open,
    this.meta,
    this.guard,
  });

  final String title;
  final String blurb;

  /// Roughly how long it takes; shown on the card and in search.
  final int minutes;
  final IconData icon;
  final ToolkitArtKind art;
  final WidgetBuilder open;

  /// Replaces the "N min" line on the card when set ("Premium · 12 min").
  final String? meta;

  /// Asked before opening; return false to stop (after showing the
  /// upgrade sheet, say). Null means always open.
  final bool Function(BuildContext context)? guard;
}

/// A short read on one idea behind a toolkit.
class ToolkitLesson {
  const ToolkitLesson({
    required this.title,
    required this.blurb,
    required this.minutes,
    required this.art,
    required this.paragraphs,
  });

  final String title;
  final String blurb;
  final int minutes;
  final ToolkitArtKind art;
  final List<String> paragraphs;
}

/// Free, reputable self-help material from outside the app.
class ToolkitResource {
  const ToolkitResource({
    required this.title,
    required this.by,
    required this.blurb,
    required this.url,
  });

  final String title;
  final String by;
  final String blurb;
  final String url;
}
