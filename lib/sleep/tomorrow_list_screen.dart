import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../journal/journal_repository.dart';
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

  String get _summary {
    final top = [
      for (final (i, c) in _top.indexed)
        if (c.text.trim().isNotEmpty) '${i + 1}. ${c.text.trim()}',
    ];
    return 'Tomorrow:\n${top.isEmpty ? '—' : top.join('\n')}\n\n'
        'Letting go tonight: ${_letGo.text.trim().isEmpty ? '—' : _letGo.text.trim()}\n'
        'One good thing today: ${_good.text.trim().isEmpty ? '—' : _good.text.trim()}';
  }

  Future<void> _done({required bool toJournal}) async {
    setState(() => _saving = true);
    await _persist();
    if (!mounted) return;
    var saved = true;
    if (toJournal) {
      saved = await toolkitSaveToJournal(
        context,
        title: 'Put the day down',
        content: _summary,
        repository: widget.journal,
      );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Written down. It\'ll keep till morning.'),
          ),
        );
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
    if (!_loaded) {
      return const ToolkitScaffold(
        accent: sleepAccent,
        title: 'Put the day down',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    return ToolkitScaffold(
      accent: sleepAccent,
      title: 'Put the day down',
      bottom: Row(
        children: [
          TextButton(
            onPressed: !_hasSomething || _saving
                ? null
                : () => _done(toJournal: true),
            child: const Text('Save to journal'),
          ),
          const Spacer(),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: !_hasSomething || _saving
                  ? null
                  : () => _done(toJournal: false),
              child: const Text('Done for tonight'),
            ),
          ),
        ],
      ),
      children: [
        const ToolkitSection(
          title: 'Out of your head, onto the page',
          subtitle:
              'The 2am mind is a to-do list with nowhere to go. Give '
              'it somewhere. Three things for tomorrow — not ten — one '
              'thing you\'re choosing not to carry tonight, and one thing '
              'that was good today, however small.',
        ),
        const _Label('Tomorrow\'s three'),
        for (final (i, c) in _top.indexed) _field(c, 'Thing ${i + 1}'),
        const SizedBox(height: 6),
        const _Label('Tonight I\'m letting go of'),
        _field(_letGo, 'A worry that can wait until daylight', lines: 2),
        const SizedBox(height: 6),
        const _Label('One good thing today'),
        _field(_good, 'Small counts', lines: 2),
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
