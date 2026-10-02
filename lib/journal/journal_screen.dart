import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../home/home_ui.dart';
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final days = today.difference(that).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final year = d.year == now.year ? '' : ' ${d.year}';
    return '${d.day} ${months[d.month - 1]}$year';
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
                          : 'Untitled',
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
    if (_error) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.cloud_off_rounded, size: 40, color: c.border),
          const SizedBox(height: 14),
          Text(
            'Couldn\'t load your journal.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: c.textMuted),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton(
              onPressed: _load,
              child: const Text('Try again'),
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
            'Your space is ready.\nWrite your first entry whenever you like.',
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
                  'Journal',
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
                      ? 'A private place for whatever\'s on your mind.'
                      : 'A private place for whatever\'s on your mind · '
                          '$count/$freeJournalEntryLimit free entries used.',
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
