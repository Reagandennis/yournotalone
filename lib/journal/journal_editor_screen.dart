import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import 'journal_repository.dart';

/// Write or edit a single journal entry. Pops with `true` when the list
/// should refresh (saved or deleted).
class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({
    super.key,
    this.entry,
    this.initialTitle,
    this.initialContent,
  });

  final JournalEntry? entry;
  final String? initialTitle;
  final String? initialContent;

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  final _repo = JournalRepository();
  late final TextEditingController _title;
  late final TextEditingController _content;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
      text: widget.entry?.title ?? widget.initialTitle,
    );
    _content = TextEditingController(
      text: widget.entry?.content ?? widget.initialContent,
    );
    _content.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final title = _title.text.trim();
    try {
      if (widget.entry == null) {
        await _repo.create(
          title: title.isEmpty ? null : title,
          content: _content.text.trim(),
        );
      } else {
        await _repo.update(
          widget.entry!.id,
          title: title.isEmpty ? null : title,
          content: _content.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t save your entry — check your connection.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Brand.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.delete(widget.entry!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Couldn\'t delete the entry — check your connection.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _content.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const BackChip(),
                      const Spacer(),
                      if (widget.entry != null)
                        IconButton(
                          tooltip: 'Delete entry',
                          onPressed: _saving ? null : _confirmDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 22,
                            color: Brand.red,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Brand.ink,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Title (optional)',
                      hintStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Brand.border,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const PillarStripe(width: 90, height: 4),
                  const SizedBox(height: 14),
                  Expanded(
                    child: TextField(
                      controller: _content,
                      autofocus: widget.entry == null,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Brand.ink,
                        height: 1.65,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Whatever\'s on your mind — this space is '
                            'yours alone.',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: Brand.textMuted,
                          height: 1.65,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 24),
                    child: AuthSubmitButton(
                      label: 'Save entry',
                      loading: _saving,
                      onPressed: canSave ? _save : null,
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
