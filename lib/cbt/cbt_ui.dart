import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../home/home_ui.dart';
import '../journal/journal_repository.dart';
import 'cbt_art.dart';

/// The warm header colour of the toolkit — the CBT card's red on Explore.
const cbtAccent = Color(0xFFC53C26);

/// The soft card colour behind each tool, as in the reference design.
const cbtCardColor = Color(0xFFF6F3EF);
const cbtRadius = 18.0;

/// A toolkit page: a solid, warm header bar with the title, then a
/// scrolling body. [actions] sit in the bar.
class CbtScaffold extends StatelessWidget {
  const CbtScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.bottom,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 32),
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  /// Pinned under the list, for a step's main button.
  final Widget? bottom;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cbtAccent,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        title: Text(title),
        actions: actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(padding: padding, children: children),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// A list card in the reference style: title and two lines of copy on the
/// left, an illustration bleeding off the right edge.
class CbtCard extends StatelessWidget {
  const CbtCard({
    super.key,
    required this.title,
    required this.blurb,
    required this.art,
    required this.onTap,
    this.meta,
  });

  final String title;
  final String blurb;
  final CbtArtKind art;
  final VoidCallback onTap;

  /// A small line under the blurb: "4 min", "External link".
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: cbtCardColor,
        borderRadius: BorderRadius.circular(cbtRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 116),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 8, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Brand.ink,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            blurb,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Brand.textMuted,
                              height: 1.4,
                            ),
                          ),
                          if (meta != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              meta!,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: cbtAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // The painter draws past its own square and the card
                  // clips, so the shapes run off the right edge as in the
                  // reference.
                  SizedBox(
                    width: 108,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: CbtArt(kind: art, size: 104),
                      ),
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

/// Section heading inside the toolkit, with an optional line under it.
class CbtSection extends StatelessWidget {
  const CbtSection({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Brand.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: Brand.textMuted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Step 2 of 6" and the question for that step, at the top of a guided
/// exercise.
class CbtStepHeader extends StatelessWidget {
  const CbtStepHeader({
    super.key,
    required this.step,
    required this.of,
    required this.title,
    this.hint,
  });

  final int step;
  final int of;
  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 1; i <= of; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == of ? 0 : 5),
                  decoration: BoxDecoration(
                    color: i <= step ? cbtAccent : Brand.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Step $step of $of',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cbtAccent,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: Brand.ink,
            height: 1.25,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            style: const TextStyle(
              fontSize: 13.5,
              color: Brand.textMuted,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

/// A selectable pill, the same shape as the therapy screen's.
class CbtPill extends StatelessWidget {
  const CbtPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Brand.ink : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? Brand.ink : Brand.border,
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : Brand.ink,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : Brand.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet box for a summary or a tip.
class CbtNote extends StatelessWidget {
  const CbtNote({super.key, required this.child, this.tint = cbtCardColor});

  final Widget child;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    // A Material rather than a Container, so list tiles and ink inside it
    // draw properly.
    return Material(
      color: tint,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Saves an exercise to the journal, respecting the free plan's cap.
/// Returns true when it was saved.
Future<bool> cbtSaveToJournal(
  BuildContext context, {
  required String title,
  required String content,
  JournalRepository? repository,
}) async {
  final journal = repository ?? JournalRepository();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final count = await journal.countEntries();
    if (!context.mounted) return false;
    if (!journalCapAllows(context, count)) return false;
    await journal.create(title: title, content: content);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Saved to your journal.')));
    return true;
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            errorMessage(e, 'Couldn\'t save — check your connection.'),
          ),
        ),
      );
    return false;
  }
}

/// Opens an outside link in the browser, saying so if it can't.
Future<void> cbtOpenLink(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) throw Exception('not launched');
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text('Couldn\'t open $url')));
  }
}
