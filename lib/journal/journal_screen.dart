import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
import 'journal_editor_screen.dart';
import 'journal_repository.dart';

/// The journal: every entry the user has written, newest first.
/// Free plan includes [_freeLimit] entries; Premium is unlimited.
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _repo = JournalRepository();
  List<JournalEntry>? _entries;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isPremium => isPremiumUser();

  Future<void> _load() async {
    setState(() {
      _entries = null;
      _error = false;
    });
    try {
      final entries = await _repo.fetchEntries();
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _openEditor({
    JournalEntry? entry,
    String? initialTitle,
    String? initialContent,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => JournalEditorScreen(
          entry: entry,
          initialTitle: initialTitle,
          initialContent: initialContent,
        ),
      ),
    );
    if (changed == true) _load();
  }

  void _newEntry() {
    if (!journalCapAllows(context, _entries?.length ?? 0)) return;
    _openEditor();
  }


  String _dateLabel(DateTime d) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final days = today.difference(that).inDays;
    if (days == 0) return l10n.journalToday;
    if (days == 1) return l10n.journalYesterday;
    final thisYear = d.year == now.year;
    final locale = l10n.localeName;
    // English keeps its day-first "5 Jan"; other languages get their own
    // short date.
    final format = locale.startsWith('en')
        ? DateFormat(thisYear ? 'd MMM' : 'd MMM y', locale)
        : (thisYear ? DateFormat.MMMd(locale) : DateFormat.yMMMd(locale));
    return format.format(d);
  }

  Widget _entryCard(JournalEntry entry) {
    final c = context.brand;
    final snippet = entry.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openEditor(entry: entry),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.title?.trim().isNotEmpty == true
                          ? entry.title!.trim()
                          : context.l10n.journalUntitled,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _dateLabel(entry.createdAt),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: c.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    final c = context.brand;
    final l10n = context.l10n;
    if (_error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.cloud_off_rounded, size: 40, color: c.border),
          const SizedBox(height: 14),
          Text(
            l10n.journalLoadFailed,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textMuted),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: _load,
              child: Text(l10n.commonTryAgain),
            ),
          ),
        ],
      );
    }
    final entries = _entries;
    if (entries == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: CircularProgressIndicator(color: c.ink, strokeWidth: 2.6),
        ),
      );
    }
    if (entries.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.edit_note_rounded, size: 40, color: c.border),
          const SizedBox(height: 14),
          Text(
            l10n.journalEmpty,
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 14, color: c.textMuted, height: 1.6),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in entries) ...[
          _entryCard(entry),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final count = _entries?.length ?? 0;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _newEntry,
        backgroundColor: c.ink,
        foregroundColor: c.onInk,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 100),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BackChip(),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.journalTitle,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                Text(
                  _isPremium
                      ? l10n.journalIntro
                      : l10n.journalIntroFree(count, freeJournalEntryLimit),
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                _body(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
