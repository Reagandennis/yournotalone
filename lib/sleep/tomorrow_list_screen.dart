import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../journal/journal_repository.dart';
import '../l10n/l10n.dart';
import '../toolkit/toolkit_ui.dart';
import 'sleep_content.dart';

/// Tonight's page: three things for tomorrow, one thing let go, one good
/// thing from today. Saved on the phone per night, and to the journal if
/// the person wants it kept.
class TomorrowListScreen extends StatefulWidget {
  const TomorrowListScreen({super.key, this.journal, this.clock});

  final JournalRepository? journal;
  final DateTime Function()? clock;

  @override
  State<TomorrowListScreen> createState() => _TomorrowListScreenState();
}

class _TomorrowListScreenState extends State<TomorrowListScreen> {
  final _top = List.generate(3, (_) => TextEditingController());
  final _letGo = TextEditingController();
  final _good = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  String get _key {
    final d = widget.clock?.call() ?? DateTime.now();
    return 'sleep.tomorrow.${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final raw = prefs.getString(_key);
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final top = (m['top'] as List).cast<String>();
        for (var i = 0; i < 3 && i < top.length; i++) {
          _top[i].text = top[i];
        }
        _letGo.text = m['letGo'] as String? ?? '';
        _good.text = m['good'] as String? ?? '';
      }
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    for (final c in [..._top, _letGo, _good]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasSomething =>
      _top.any((c) => c.text.trim().isNotEmpty) ||
      _letGo.text.trim().isNotEmpty ||
      _good.text.trim().isNotEmpty;

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'top': [for (final c in _top) c.text.trim()],
        'letGo': _letGo.text.trim(),
        'good': _good.text.trim(),
      }),
    );
  }

  String _summary(AppLocalizations l10n) {
    final top = [
      for (final (i, c) in _top.indexed)
        if (c.text.trim().isNotEmpty) '${i + 1}. ${c.text.trim()}',
    ];
    return l10n.tomorrowListSummary(
      top.isEmpty ? '—' : top.join('\n'),
      _letGo.text.trim().isEmpty ? '—' : _letGo.text.trim(),
      _good.text.trim().isEmpty ? '—' : _good.text.trim(),
    );
  }

  Future<void> _done({required bool toJournal}) async {
    setState(() => _saving = true);
    await _persist();
    if (!mounted) return;
    var saved = true;
    if (toJournal) {
      saved = await toolkitSaveToJournal(
        context,
        title: context.l10n.tomorrowListTitle,
        content: _summary(context.l10n),
        repository: widget.journal,
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.l10n.tomorrowListSaved)));
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop();
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: lines,
        maxLength: 160,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, counterText: ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_loaded) {
      return ToolkitScaffold(
        accent: sleepAccent,
        title: l10n.tomorrowListTitle,
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    return ToolkitScaffold(
      accent: sleepAccent,
      title: l10n.tomorrowListTitle,
      bottom: Row(
        children: [
          TextButton(
            onPressed: !_hasSomething || _saving
                ? null
                : () => _done(toJournal: true),
            child: Text(l10n.tomorrowListSaveToJournal),
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: !_hasSomething || _saving
                  ? null
                  : () => _done(toJournal: false),
              child: Text(l10n.tomorrowListDoneForTonight),
            ),
          ),
        ],
      ),
      children: [
        ToolkitSection(
          title: l10n.tomorrowListIntroTitle,
          subtitle: l10n.tomorrowListIntroHint,
        ),
        _Label(l10n.tomorrowListTopThree),
        for (final (i, c) in _top.indexed)
          _field(c, l10n.tomorrowListThing(i + 1)),
        const SizedBox(height: 6),
        _Label(l10n.tomorrowListLetGo),
        _field(_letGo, l10n.tomorrowListLetGoHint, lines: 2),
        const SizedBox(height: 6),
        _Label(l10n.tomorrowListGood),
        _field(_good, l10n.tomorrowListGoodHint, lines: 2),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.brand.ink,
        ),
      ),
    );
  }
}
