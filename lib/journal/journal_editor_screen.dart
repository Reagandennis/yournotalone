import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../brand_layout.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
import '../unsaved_work.dart';
import 'journal_drafts.dart';
import 'journal_repository.dart';

/// Write or edit a single journal entry. Pops with `true` when the list
/// should refresh (saved or deleted).
///
/// Until it's saved, the writing is also kept on the phone as a draft and
/// offered back the next time this entry (or a new one) is opened, and
/// leaving asks first — an entry used to vanish with one back swipe, or
/// with leaving after a save that failed offline.
class JournalEditorScreen extends StatefulWidget {
  const JournalEditorScreen({
    super.key,
    this.entry,
    this.initialTitle,
    this.initialContent,
    this.repository,
    this.drafts,
  });

  final JournalEntry? entry;
  final String? initialTitle;
  final String? initialContent;

  /// Injectable so saving and drafts can be exercised without a backend.
  final JournalRepository? repository;
  final JournalDrafts? drafts;

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  late final _repo = widget.repository ?? JournalRepository();
  late final _drafts = widget.drafts ?? JournalDrafts();
  late final TextEditingController _title;
  late final TextEditingController _content;
  bool _saving = false;

  /// What the editor opened with — the saved entry, or a prompt's first
  /// line. Anything different from it isn't saved yet.
  late final String _savedTitle;
  late final String _savedContent;

  /// Set once the entry is saved, deleted or discarded, so nothing writes
  /// the draft back on the way out.
  bool _closing = false;

  /// Set once a draft left from last time has been offered back, so
  /// nothing overwrites it before the person has chosen.
  bool _draftOffered = false;
  Timer? _draftTimer;
  late final AppLifecycleListener _lifecycle;

  String? get _entryId => widget.entry?.id;

  bool get _hasUnsavedWork =>
      _title.text.trim() != _savedTitle.trim() ||
      _content.text.trim() != _savedContent.trim();

  @override
  void initState() {
    super.initState();
    _savedTitle = widget.entry?.title ?? widget.initialTitle ?? '';
    _savedContent = widget.entry?.content ?? widget.initialContent ?? '';
    _title = TextEditingController(text: _savedTitle);
    _content = TextEditingController(text: _savedContent);
    _title.addListener(_onEdited);
    _content.addListener(_onEdited);
    // Going to the background is when a phone kills an app, so a waiting
    // draft is written then rather than left on the timer.
    _lifecycle = AppLifecycleListener(onHide: () {
      if (_draftTimer != null) _keepDraft();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerDraft());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    // Leaving some other way than back (the app's stack replaced, say)
    // still keeps what was written.
    if (_draftTimer != null) _keepDraft();
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _onEdited() {
    setState(() {});
    if (_closing) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), _keepDraft);
  }

  /// Writes the draft now, or forgets it once the text is back to what's
  /// saved.
  void _keepDraft() {
    _draftTimer?.cancel();
    _draftTimer = null;
    if (_closing || !_draftOffered) return;
    if (_hasUnsavedWork) {
      _drafts.save(
        _entryId,
        JournalDraft(title: _title.text, content: _content.text),
      );
    } else {
      _drafts.clear(_entryId);
    }
  }

  void _forgetDraft() {
    _closing = true;
    _draftTimer?.cancel();
    _draftTimer = null;
    _drafts.clear(_entryId);
  }

  /// Offers back writing left here unsaved last time. Only an explicit
  /// Discard throws it away: closing the dialog any other way restores it.
  Future<void> _offerDraft() async {
    try {
      await _offerDraftIfAny();
    } finally {
      _draftOffered = true;
    }
  }

  Future<void> _offerDraftIfAny() async {
    final draft = await _drafts.load(_entryId);
    if (draft == null || !mounted) return;
    if (draft.title.trim() == _savedTitle.trim() &&
        draft.content.trim() == _savedContent.trim()) {
      // Nothing in it that isn't saved already.
      await _drafts.clear(_entryId);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.journalDraftTitle),
        content: Text(context.l10n.journalDraftBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.brand.red),
            child: Text(context.l10n.commonDiscard),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.journalDraftCarryOn),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (discard == true) {
      await _drafts.clear(_entryId);
      return;
    }
    _title.text = draft.title;
    _content.text = draft.content;
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
      _forgetDraft();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // The words stay on screen and, as a draft, on the phone.
      _keepDraft();
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage(e, context.l10n.journalEditorSaveFailed),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.journalEditorDeleteTitle),
        content: Text(context.l10n.journalEditorDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.brand.red),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.delete(widget.entry!.id);
      _forgetDraft();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage(e, context.l10n.journalEditorDeleteFailed),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final canSave = _content.text.trim().isNotEmpty;
    return UnsavedWorkGuard(
      hasUnsavedWork: _hasUnsavedWork && !_closing,
      onDiscard: _forgetDraft,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kReadableMaxWidth),
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
                            tooltip: l10n.journalEditorDeleteTooltip,
                            onPressed: _saving ? null : _confirmDelete,
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 22,
                              color: c.red,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: l10n.journalEditorTitleHint,
                        hintStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: c.border,
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
                        style: TextStyle(
                          fontSize: 15,
                          color: c.ink,
                          height: 1.65,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: l10n.journalEditorBodyHint,
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: c.textMuted,
                            height: 1.65,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 24),
                      child: AuthSubmitButton(
                        label: l10n.journalEditorSave,
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
      ),
    );
  }
}
