import 'package:flutter/material.dart';

import '../home/home_ui.dart';
import 'journal_editor_screen.dart';
import 'journal_repository.dart';

/// Opens a new journal entry, enforcing the free-plan cap first.
///
/// Every route into a *new* entry goes through here — the journal list, the
/// hub's blank page, a prompt, and the end of a session. The cap used to
/// live in the list alone, so the other routes handed out unlimited entries.
Future<void> openNewJournalEntry(
  BuildContext context, {
  String? title,
  String? content,
  JournalRepository? journal,
  int? knownCount,
}) async {
  var count = knownCount;
  if (count == null) {
    try {
      count = await (journal ?? JournalRepository()).countEntries();
    } catch (_) {
      // Can't count — don't lock someone out of their own journal over it.
      count = 0;
    }
  }
  if (!context.mounted) return;
  if (!journalCapAllows(context, count)) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => JournalEditorScreen(
        initialTitle: title,
        initialContent: content,
      ),
    ),
  );
}
