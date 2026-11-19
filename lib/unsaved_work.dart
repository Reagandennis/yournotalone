import 'package:flutter/material.dart';

import 'brand.dart';
import 'l10n/l10n.dart';

/// Asks before throwing away something the person wrote and hasn't saved.
/// True means they chose to discard it; dismissing the dialog keeps it.
Future<bool> confirmDiscardUnsaved(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.unsavedLeaveTitle),
      content: Text(context.l10n.unsavedLeaveBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.unsavedKeepWriting),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: context.brand.red),
          child: Text(context.l10n.commonDiscard),
        ),
      ],
    ),
  );
  return discard == true;
}

/// Wraps a screen people write on, so leaving it — the back button, a
/// back swipe, Android's back, or anything that calls `maybePop` — asks
/// first while [hasUnsavedWork] is true, instead of silently losing it.
///
/// Rebuild it as the writing changes: back is only held while
/// [hasUnsavedWork] is true, so an empty screen still swipes away freely.
/// A screen that leaves after saving should use `Navigator.pop`, which
/// this doesn't stop.
class UnsavedWorkGuard extends StatelessWidget {
  const UnsavedWorkGuard({
    super.key,
    required this.hasUnsavedWork,
    required this.child,
    this.onDiscard,
  });

  final bool hasUnsavedWork;
  final Widget child;

  /// Runs when the person chooses to discard, just before the screen
  /// closes — e.g. to forget a draft kept on the phone.
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasUnsavedWork,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!await confirmDiscardUnsaved(context) || !context.mounted) return;
        onDiscard?.call();
        Navigator.of(context).pop(result);
      },
      child: child,
    );
  }
}
